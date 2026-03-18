import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet_1 = accounts.get("wallet_1")!;
const wallet_2 = accounts.get("wallet_2")!;
const wallet_3 = accounts.get("wallet_3")!;

const condContract = `${deployer}.stream-conditions`;
const coreContract = `${deployer}.stream-core`;

describe("stream-conditions tests", () => {
  it("ensures BTC threshold blocks claims until block is reached", () => {
    // Current block is 1. Set threshold to 10.
    const createCondition = simnet.callPublicFn(
      condContract,
      "create-condition",
      [
        Cl.uint(1), // CONDITION_BTC_THRESHOLD
        Cl.uint(10), // Threshold block
        Cl.uint(0),
        Cl.none(),
        Cl.uint(1), // stream id
        Cl.principal(wallet_1) // sender
      ],
      coreContract // Caller must be core-contract or mock it
    );
    
    expect(createCondition.result).toBeOk(Cl.uint(1)); // cond-id 1

    // Check conditions at block 1 -> should fail (ERR_THRESHOLD_NOT_MET = 3004)
    let check = simnet.callPublicFn(condContract, "check-conditions", [Cl.uint(1)], wallet_2);
    expect(check.result).toBeErr(Cl.uint(3004));

    // Mine 10 blocks
    simnet.mineEmptyBlocks(10);

    // Check conditions at block 11 -> should pass
    check = simnet.callPublicFn(condContract, "check-conditions", [Cl.uint(1)], wallet_2);
    expect(check.result).toBeOk(Cl.bool(true));
  });

  it("ensures milestone unlocks require verifier approval", () => {
    const verifier = wallet_3;
    
    // Create milestone condition
    const create = simnet.callPublicFn(
      condContract,
      "create-condition",
      [
        Cl.uint(3), // CONDITION_MILESTONE
        Cl.uint(5), // 5 total milestones
        Cl.uint(0),
        Cl.some(Cl.principal(verifier)), // verifier
        Cl.uint(2), // stream id
        Cl.principal(wallet_1) // sender
      ],
      coreContract
    );
    
    const condId = 2;
    expect(create.result).toBeOk(Cl.uint(condId));

    // Claim before approval -> fails (ERR_MILESTONE_NOT_APPROVED = 3006)
    let check = simnet.callPublicFn(condContract, "check-conditions", [Cl.uint(condId)], wallet_2);
    expect(check.result).toBeErr(Cl.uint(3006));

    // Non-verifier tries to approve -> fails (ERR_UNAUTHORIZED = 3001)
    let approve = simnet.callPublicFn(condContract, "approve-milestone", [Cl.uint(condId), Cl.uint(1)], wallet_1);
    expect(approve.result).toBeErr(Cl.uint(3001));

    // Verifier approves milestone 1
    approve = simnet.callPublicFn(condContract, "approve-milestone", [Cl.uint(condId), Cl.uint(1)], verifier);
    expect(approve.result).toBeOk(Cl.bool(true));

    // Claim after approval -> passes
    check = simnet.callPublicFn(condContract, "check-conditions", [Cl.uint(condId)], wallet_2);
    expect(check.result).toBeOk(Cl.bool(true));
  });

  it("ensures pausable streams can be paused and resumed by sender only", () => {
    // Create pausable condition
    const create = simnet.callPublicFn(
      condContract,
      "create-condition",
      [
        Cl.uint(4), // CONDITION_PAUSABLE
        Cl.uint(0),
        Cl.uint(0),
        Cl.none(),
        Cl.uint(3), // stream id
        Cl.principal(wallet_1) // sender
      ],
      coreContract
    );
    
    const condId = 3;
    expect(create.result).toBeOk(Cl.uint(condId));

    // Initially passes
    let check = simnet.callPublicFn(condContract, "check-conditions", [Cl.uint(condId)], wallet_2);
    expect(check.result).toBeOk(Cl.bool(true));

    // Non-sender tries to pause -> fails
    let pause = simnet.callPublicFn(condContract, "pause-stream", [Cl.uint(condId)], wallet_2);
    expect(pause.result).toBeErr(Cl.uint(3001)); // ERR_UNAUTHORIZED

    // Sender pauses
    pause = simnet.callPublicFn(condContract, "pause-stream", [Cl.uint(condId)], wallet_1);
    expect(pause.result).toBeOk(Cl.bool(true));

    // Claim while paused -> fails (ERR_STREAM_PAUSED = 3007)
    check = simnet.callPublicFn(condContract, "check-conditions", [Cl.uint(condId)], wallet_2);
    expect(check.result).toBeErr(Cl.uint(3007));

    // Sender resumes
    let resume = simnet.callPublicFn(condContract, "resume-stream", [Cl.uint(condId)], wallet_1);
    expect(resume.result).toBeOk(Cl.bool(true));

    // Claim after resume -> passes
    check = simnet.callPublicFn(condContract, "check-conditions", [Cl.uint(condId)], wallet_2);
    expect(check.result).toBeOk(Cl.bool(true));
  });
});
