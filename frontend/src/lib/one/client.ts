import { SuiClient } from '@mysten/sui.js/client';

export const suiClient = new SuiClient({
  url: 'https://rpc-testnet.onelabs.cc:443',
});
