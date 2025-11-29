import { ReactNode } from 'react';
import { SuiClientProvider, WalletProvider, createNetworkConfig } from '@mysten/dapp-kit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { getFullnodeUrl } from '@mysten/sui.js/client';
import '@mysten/dapp-kit/dist/index.css';

const { networkConfig } = createNetworkConfig({
  devnet: { url: getFullnodeUrl('devnet') },
  testnet: { url: getFullnodeUrl('testnet') },
  mainnet: { url: getFullnodeUrl('mainnet') },
});

const queryClient = new QueryClient();

export function Providers({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <SuiClientProvider networks={networkConfig} defaultNetwork="devnet">
        <WalletProvider>{children}</WalletProvider>
      </SuiClientProvider>
    </QueryClientProvider>
  );
}
