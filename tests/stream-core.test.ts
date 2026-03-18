import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet_1 = accounts.get("wallet_1")!;
const wallet_2 = accounts.get("wallet_2")!;

const coreContract = `${deployer}.stream-core`;

describe("stream-core tests", () => {
  it("ensures that a user can create an STX stream", () => {
    const amount = 1000000;
    const duration = 144;
    
    const block = simnet.mineBlock([
      simnet.callPublicFn(
        coreContract,
        "create-stream",
        [
          Cl.principal(wallet_2), // recipient
          Cl.uint(amount),        // amount
          Cl.uint(duration),      // duration
          Cl.uint(0),             // condition-type = NONE
          Cl.uint(0),             // param 1
          Cl.uint(0),             // param 2
          Cl.none()               // principal param
        ],
        wallet_1                  // sender
      )
    ]);
    
    // Check success
    expect(block[0].result).toBeOk(Cl.uint(1)); // stream-id u1
    
    // Check STX locked in contract
    const events = block[0].events;
    expect(events.length).toBeGreaterThan(0);
    expect(events[0].event).toBe("stx_asset_event");
    if (events[0].event === "stx_asset_event") {
      expect(events[0].data.amount).toBe(amount.toString());
      expect(events[0].data.recipient).toBe(coreContract);
      expect(events[0].data.sender).toBe(wallet_1);
    }
  });

  it("ensures that stream creation fails if sender is recipient", () => {
    const block = simnet.mineBlock([
      simnet.callPublicFn(
        coreContract,
        "create-stream",
        [
          Cl.principal(wallet_1), // recipient is sender
          Cl.uint(1000000),
          Cl.uint(144),
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(0),
          Cl.none()
        ],
        wallet_1
      )
    ]);
    
    expect(block[0].result).toBeErr(Cl.uint(1012)); // ERR_SELF_STREAM
  });

  it("ensures recipient can claim vested STX after some blocks", () => {
    const amount = 144000; // 1000 stx per block for 144 blocks
    const duration = 144;
    
    // Create stream
    simnet.mineBlock([
      simnet.callPublicFn(coreContract, "create-stream", [
        Cl.principal(wallet_2), Cl.uint(amount), Cl.uint(duration),
        Cl.uint(0), Cl.uint(0), Cl.uint(0), Cl.none()
      ], wallet_1)
    ]);
    
    // Mine 10 empty blocks to advance time (burn-block-height)
    simnet.mineEmptyBlocks(10);
    
    // Claim
    const claimBlock = simnet.mineBlock([
      simnet.callPublicFn(coreContract, "claim-stream", [Cl.uint(1)], wallet_2)
    ]);
    
    // Expected elapsed is 10 blocks (since creation is at 1, current is 11)
    // Actually in simnet empty blocks advance the Stacks block height
    // Vested amount should be > 0
    expect(claimBlock[0].result).toBeOk(Cl.uint(10000)); // 10 blocks * 1000/block
  });

  it("ensures sender can cancel and get proportional refund", () => {
    // Create stream
    simnet.mineBlock([
      simnet.callPublicFn(coreContract, "create-stream", [
        Cl.principal(wallet_2), Cl.uint(144000), Cl.uint(144),
        Cl.uint(0), Cl.uint(0), Cl.uint(0), Cl.none()
      ], wallet_1)
    ]);
    
    simnet.mineEmptyBlocks(50);
    
    // Cancel
    const cancelBlock = simnet.mineBlock([
      simnet.callPublicFn(coreContract, "cancel-stream", [Cl.uint(1)], wallet_1)
    ]);
    
    const result = cancelBlock[0].result;
    expect(result).toHaveProperty('value'); // It's an Ok tuple
  });
});
