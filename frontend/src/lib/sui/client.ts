import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';

// Sui devnet network
export const suiClient = new SuiClient({
  url: getFullnodeUrl('devnet'),
});