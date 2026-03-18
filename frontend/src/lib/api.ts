import { StacksMainnet, StacksTestnet, StacksMocknet } from '@stacks/network';
import { callReadOnlyFunction, cvToJSON, intCV } from '@stacks/transactions';

// Use devnet/mocknet for local Clarinet testing
export const network = new StacksMocknet();
export const CONTRACT_ADDRESS = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'; // Deployer from Devnet.toml
export const CORE_CONTRACT_NAME = 'stream-core';
export const CONDITIONS_CONTRACT_NAME = 'stream-conditions';
export const NFT_CONTRACT_NAME = 'stream-nft';

// Helper to fetch current block height from the Stacks node API
export const getCurrentBlockHeight = async (): Promise<number> => {
  try {
    const response = await fetch(`${network.coreApiUrl}/v2/info`);
    const data = await response.json();
    return data.burn_block_height; // DrizzleonStacks uses burn_block_height
  } catch (error) {
    console.error('Error fetching block height:', error);
    return 0;
  }
};

// Read-only call to get stream info
export const getStreamInfo = async (streamId: number) => {
  try {
    const result = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CORE_CONTRACT_NAME,
      functionName: 'get-stream',
      functionArgs: [intCV(streamId)],
      network,
      senderAddress: CONTRACT_ADDRESS,
    });
    return cvToJSON(result);
  } catch (error) {
    console.error(`Error fetching stream ${streamId}:`, error);
    return null;
  }
};

// Read-only call to get vested amount
export const getVestedAmount = async (streamId: number) => {
  try {
    const result = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CORE_CONTRACT_NAME,
      functionName: 'get-vested-amount',
      functionArgs: [intCV(streamId)],
      network,
      senderAddress: CONTRACT_ADDRESS,
    });
    return cvToJSON(result);
  } catch (error) {
    return null;
  }
};
