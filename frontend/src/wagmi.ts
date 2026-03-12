import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { sepolia } from 'viem/chains';

// Supported chains: Sepolia testnet
export const SUPPORTED_CHAIN_IDS = [sepolia.id] as const;

export const config = getDefaultConfig({
  appName: 'Aura Protocol',
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? 'aura-dev-placeholder',
  chains: [sepolia],
  transports: {
    [sepolia.id]: http('/rpc'),
  },
  ssr: false,
});
