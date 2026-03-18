# DrizzleonStacks

Bitcoin-anchored payment streaming on Stacks.

Continuous, block-by-block value transfer of STX and SIP-010 tokens between two principals. Stream activation governed entirely by on-chain primitives — no oracles, no off-chain infrastructure.

## Architecture

Three Clarity contracts, each with a single responsibility:

| Contract | Role |
|---|---|
| `stream-core` | Stream lifecycle: create, claim, cancel, renew. Source of truth for all stream state. |
| `stream-conditions` | Release rules: Bitcoin-block threshold, cliff-then-linear vesting, milestone unlock, sender pause. |
| `stream-nft` | SIP-009 NFT positions. Recipient's claim rights as tradeable tokens. |

## Time Model

All scheduling uses `burn-block-height` (Bitcoin block height). Approximate conversions:

- 6 blocks ≈ 1 hour (minimum stream duration)
- 144 blocks ≈ 1 day
- 1,008 blocks ≈ 1 week
- 4,320 blocks ≈ 30 days

## Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) (latest)
- [Node.js](https://nodejs.org/) 18+

### Local Development

```bash
# Run contract tests
clarinet test

# Check contracts
clarinet check

# Open Clarinet console
clarinet console
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173` in your browser. Connect a Stacks wallet (Leather or Xverse).

## Contract Interfaces

### Creating a Stream

```clarity
;; STX stream with no conditions
(contract-call? .stream-core create-stream
  recipient      ;; principal
  u1000000       ;; amount in microSTX
  u144           ;; duration in blocks (~1 day)
  u0             ;; condition type (0 = none)
  u0 u0 none     ;; condition params (unused)
)
```

### Claiming Vested Funds

```clarity
;; Recipient claims available funds
(contract-call? .stream-core claim-stream u1)
```

### Cancelling a Stream

```clarity
;; Sender cancels — vested goes to recipient, rest refunded
(contract-call? .stream-core cancel-stream u1)
```

## Security

- All private keys, mnemonics, and deployment configs are gitignored
- Clarity's decidability eliminates reentrancy risks
- Native uint overflow protection on all arithmetic
- Atomic STX/token transfers — failed transfer reverts entire transaction
- NFT ownership changes sync with stream recipient via cross-contract call

## License

MIT
