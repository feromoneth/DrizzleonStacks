import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet_1 = accounts.get("wallet_1")!;
const wallet_2 = accounts.get("wallet_2")!;

const nftContract = `${deployer}.stream-nft`;
const coreContract = `${deployer}.stream-core`;

describe("stream-nft tests", () => {
  it("ensures minting is restricted to stream-core contract", () => {
    // Direct mint by user -> fails (ERR_NOT_CORE_CONTRACT = 4005)
    let mint = simnet.callPublicFn(
      nftContract,
      "mint-stream-nft",
      [Cl.principal(wallet_1), Cl.uint(1)],
      wallet_1
    );
    expect(mint.result).toBeErr(Cl.uint(4005));

    // Mint by stream-core -> passes
    mint = simnet.callPublicFn(
      nftContract,
      "mint-stream-nft",
      [Cl.principal(wallet_1), Cl.uint(1)],
      coreContract
    );
    expect(mint.result).toBeOk(Cl.uint(1));
  });

  it("ensures owners can transfer their stream nft", () => {
    // Mint NFT to wallet_1
    let mint = simnet.callPublicFn(
      nftContract,
      "mint-stream-nft",
      [Cl.principal(wallet_1), Cl.uint(2)],
      coreContract
    );
    expect(mint.result).toBeOk(Cl.uint(2));

    // Check owner is wallet_1
    let owner = simnet.callReadOnlyFn(nftContract, "get-owner", [Cl.uint(2)], wallet_1);
    expect(owner.result).toBeOk(Cl.some(Cl.principal(wallet_1)));

    // wallet_2 tries to transfer -> fails (ERR_NOT_AUTHORIZED / ERR_WRONG_OWNER)
    let transfer = simnet.callPublicFn(
      nftContract,
      "transfer",
      [Cl.uint(2), Cl.principal(wallet_2), Cl.principal(wallet_3)],
      wallet_2
    );
    // Might fail with ERR_NOT_AUTHORIZED (4001) if sender != tx-sender or WRONG_OWNER (4004)
    // Actually the contract checks if tx-sender is sender, AND if sender owns token.
    // Here tx-sender = wallet_2, sender = wallet_2. But wallet_2 is NOT the owner.
    expect(transfer.result).toBeErr(Cl.uint(4004));

    // wallet_1 transfers to wallet_2 -> passes
    // NOTE: This call will actually try to call stream-core.update-recipient which doesn't
    // exist for stream id 2 in this test context since we mocked the minting. But the contract
    // call will only fail if stream-core fails. We'll mint through stream-core to really test.
  });

  it("ensures full integration of mint and transfer via stream-core", () => {
    // Create stream -> stream-core mints NFT automatically
    let create = simnet.callPublicFn(
      coreContract,
      "create-stream",
      [
        Cl.principal(wallet_1), // recipient
        Cl.uint(100000), Cl.uint(144), Cl.uint(0), Cl.uint(0), Cl.uint(0), Cl.none()
      ],
      deployer // sender
    );
    
    // Assume stream id 1, nft id 1 (in a clean simnet state for this stream)
    // Actually, simnet state persists across tests in some setups, but here let's get the id
    const streamIdMatch = create.result.toString().match(/\(ok u(\d+)\)/);
    const streamId = streamIdMatch ? parseInt(streamIdMatch[1]) : 1;

    // The NFT was minted to wallet_1.
    // wallet_1 transfers NFT to wallet_2
    let transfer = simnet.callPublicFn(
      nftContract,
      "transfer",
      [Cl.uint(streamId), Cl.principal(wallet_1), Cl.principal(wallet_2)],
      wallet_1
    );
    
    expect(transfer.result).toBeOk(Cl.bool(true));

    // Verify recipient updated in stream-core
    let stream = simnet.callReadOnlyFn(coreContract, "get-stream", [Cl.uint(streamId)], wallet_1);
    
    // The stream data map returned. We check that recipient is wallet_2.
    // In clarity syntax: (some { ..., recipient: wallet_2, ... })
    const resultStr = stream.result.toString();
    expect(resultStr.includes(wallet_2)).toBe(true);
  });
});

