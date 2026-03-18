import { openContractCall } from '@stacks/connect-react';
import { 
  uintCV, 
  principalCV, 
  noneCV, 
  someCV,
  PostConditionMode
} from '@stacks/transactions';
import { 
  network, 
  CONTRACT_ADDRESS, 
  CORE_CONTRACT_NAME,
  NFT_CONTRACT_NAME
} from './api';

export const createStream = (
  recipient: string,
  amount: number,
  durationBlocks: number,
  conditionType: number,
  onFinish: (data: any) => void
) => {
  openContractCall({
    network,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CORE_CONTRACT_NAME,
    functionName: 'create-stream',
    functionArgs: [
      principalCV(recipient),
      uintCV(amount),
      uintCV(durationBlocks),
      uintCV(conditionType),
      uintCV(0), // param 1
      uintCV(0), // param 2
      noneCV()   // principal param
    ],
    postConditionMode: PostConditionMode.Allow, // For STX transfer
    onFinish,
    onCancel: () => console.log('Transaction cancelled'),
  });
};

export const claimStream = (
  streamId: number,
  onFinish: (data: any) => void
) => {
  openContractCall({
    network,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CORE_CONTRACT_NAME,
    functionName: 'claim-stream',
    functionArgs: [uintCV(streamId)],
    postConditionMode: PostConditionMode.Allow, // For STX transfer
    onFinish,
  });
};

export const cancelStream = (
  streamId: number,
  onFinish: (data: any) => void
) => {
  openContractCall({
    network,
    contractAddress: CONTRACT_ADDRESS,
    contractName: CORE_CONTRACT_NAME,
    functionName: 'cancel-stream',
    functionArgs: [uintCV(streamId)],
    postConditionMode: PostConditionMode.Allow,
    onFinish,
  });
};

export const transferStreamNft = (
  streamId: number,
  sender: string,
  recipient: string,
  onFinish: (data: any) => void
) => {
  openContractCall({
    network,
    contractAddress: CONTRACT_ADDRESS,
    contractName: NFT_CONTRACT_NAME,
    functionName: 'transfer',
    functionArgs: [
      uintCV(streamId),
      principalCV(sender),
      principalCV(recipient)
    ],
    postConditionMode: PostConditionMode.Deny, // No STX transfer
    onFinish,
  });
};
