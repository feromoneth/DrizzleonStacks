# DrizzleonStacks

DrizzleonStacks is a trustless, non-custodial payment streaming protocol built on the Stacks blockchain. It enables senders to lock STX or SIP-010 assets and continuously stream them to a recipient over a defined period of time (measured in Bitcoin blocks). The protocol supports complex conditionally-released vesting schedules, such as cliff-based vesting, milestone approvals by designated verifiers, and sender-controlled pausing mechanisms. Furthermore, stream positions are tokenized as SIP-009 NFTs, allowing recipients to transfer their claim on an active stream to another address on the network. The protocol is designed for DAO payrolls, token vesting schedules, and structured trustless agreements.

## Tech Stack
* **Smart Contracts**: Clarity (Stacks Blockchain)
* **Frontend Application**: React, Vite, TypeScript
* **Blockchain Interaction**: `@stacks/transactions`, `@stacks/connect`
* **Local Contract Testing**: Clarinet

## Live Demo
*The live deployment URL is pending initialization via Vercel.*

## Contract Overview

The protocol is composed of three interconnected Clarity smart contracts:

1. **`stream-core.clar`**
   - **Purpose**: Acts as the central entry point and vault for the protocol. Handles the core lifecycle of stream creation, calculating vested balances based on `burn-block-height`, processing claims, executing partial refunds on cancellation, and renewing streams.

2. **`stream-conditions.clar`**
   - **Purpose**: Provides the oracle-free rules engine for claims. Before `stream-core` dispenses funds, it checks this contract to verify if the threshold, cliff, milestone, or pause parameters are satisfied.

3. **`stream-nft.clar`**
   - **Purpose**: A SIP-009 compliant NFT contract representing ownership of an active stream. `stream-core` mints an NFT upon stream creation. Transfers of this NFT automatically trigger a recipient update in `stream-core`.

*(Note: Mainnet deployment addresses will be added upon final production release).*

## Local Development Setup

### Prerequisites
* [Clarinet](https://github.com/hirosystems/clarinet) (for local smart contract testing and deployment)
* [Node.js](https://nodejs.org/) & `npm` (for the frontend application)
* A Stacks-compatible wallet, such as [Leather](https://leather.io/) or [Xverse](https://www.xverse.app/)

### Smart Contracts (Clarinet)

1. **Run Unit Tests**
   Execute the Vitest-based testing suite to verify all contract logic and math constraints:
   ```bash
   clarinet test
   ```

2. **Launch Local Devnet**
   Spin up a local simulated Stacks and Bitcoin chain:
   ```bash
   clarinet integrate
   ```

### Frontend Setup

1. **Install Dependencies**
   Navigate to the frontend directory and install required npm packages:
   ```bash
   cd frontend
   npm install
   ```

2. **Start Development Server**
   Run the Vite frontend locally:
   ```bash
   npm run dev
   ```
   The application will be available at `http://localhost:5173`.

## Package Usage

Interaction with the DrizzleonStacks protocol is done natively using the official `@stacks/transactions` package. No proprietary npm package is required.

**Example: Reading the current vested amount for Stream ID 1:**
```typescript
import { callReadOnlyFunction, cvToJSON, intCV } from '@stacks/transactions';
import { StacksMainnet } from '@stacks/network';

const network = new StacksMainnet();

const getVestedAmount = async (streamId: number) => {
  const result = await callReadOnlyFunction({
    contractAddress: 'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS', // Replace with deployed address
    contractName: 'stream-core',
    functionName: 'get-vested-amount',
    functionArgs: [intCV(streamId)],
    network,
    senderAddress: 'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS',
  });
  console.log('Vested Amount:', cvToJSON(result));
};
```

## Contributing Guidelines

1. **Security First**: Do not commit any private keys, `.env` files, or mainnet deployment mnemonics. Ensure all changes to contract logic include corresponding Clarinet unit tests.
2. **Branching Model**: Fork the repository, create a descriptive feature branch (e.g., `feat/add-split-streams`), and submit a pull request against the `main` branch.
3. **Commit Standards**: We utilize Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`). All commits must be granular and atomic.

## License

MIT License. See `LICENSE` for further information.
