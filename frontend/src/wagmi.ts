import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'wagmi';
import { sepolia } from 'viem/chains';

// Supported chains: Sepolia testnet
export const SUPPORTED_CHAIN_IDS = [sepolia.id] as const;

/** Dev: Vite proxies /rpc → Sepolia (vite.config.ts). Prod: same-origin /rpc has no proxy on static hosts, so use a public RPC unless overridden. */
function sepoliaHttpUrl(): string {
  const raw = (import.meta.env.VITE_SEPOLIA_RPC_URL as string | undefined)?.trim();
  if (raw && /^https?:\/\//i.test(raw)) return raw;
  if (import.meta.env.DEV) return '/rpc';
  return 'https://ethereum-sepolia.publicnode.com';
}

export const config = getDefaultConfig({
  appName: 'Aura Protocol',
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? 'aura-dev-placeholder',
  chains: [sepolia],
  transports: {
    [sepolia.id]: http(sepoliaHttpUrl()),
  },
  ssr: false,
});
