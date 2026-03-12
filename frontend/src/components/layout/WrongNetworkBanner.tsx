import { useAccount, useChainId, useSwitchChain } from 'wagmi';
import { foundry } from 'viem/chains';
import { SUPPORTED_CHAIN_IDS } from '../../wagmi';

export default function WrongNetworkBanner() {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain, isPending } = useSwitchChain();

  const isWrongNetwork =
    isConnected && !(SUPPORTED_CHAIN_IDS as readonly number[]).includes(chainId);

  if (!isWrongNetwork) return null;

  return (
    <div className="w-full bg-red-600/90 backdrop-blur-sm border-b border-red-500 px-4 py-2.5 flex items-center justify-center gap-4 text-sm font-medium text-white z-50">
      <span>
        ⚠️ Wrong network detected — contracts are deployed on{' '}
        <strong>Localhost Anvil (chain 31337)</strong>.
      </span>
      <button
        onClick={() => switchChain({ chainId: foundry.id })}
        disabled={isPending}
        className="shrink-0 px-3 py-1 rounded bg-white text-red-700 font-semibold hover:bg-red-100 transition-colors disabled:opacity-50"
      >
        {isPending ? 'Switching…' : 'Switch Network'}
      </button>
    </div>
  );
}
