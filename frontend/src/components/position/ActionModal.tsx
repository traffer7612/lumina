import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContracts } from 'wagmi';
import { parseUnits, formatUnits, type Hash, type Address } from 'viem';
import { X, ArrowRight, CheckCircle, AlertCircle, Loader2 } from 'lucide-react';
import { ceitnotEngineAbi, erc20Abi, erc4626Abi } from '../../abi/ceitnotEngine';
import { useContractAddresses, gasFor, TARGET_CHAIN_ID } from '../../lib/contracts';
import { erc20Decimals, formatToken } from '../../lib/utils';
import { formatWriteContractError, hintForEngineError } from '../../lib/formatWriteError';

export type ActionType = 'deposit' | 'withdraw' | 'borrow' | 'repay';

type Props = {
  open:      boolean;
  onClose:   () => void;
  onSuccess: () => void;
  action:    ActionType;
  marketId:  number;
  /** Address of the vault (for deposit approval) */
  vaultAddress?: `0x${string}`;
  /** Address of the debt token (for repay approval) */
  debtTokenAddress?: `0x${string}`;
  /** User's current shares balance in this market */
  sharesBalance?: bigint;
  /** User's current debt in this market */
  debtBalance?: bigint;
};

const ACTION_LABEL: Record<ActionType, string> = {
  deposit:  'Deposit Collateral',
  withdraw: 'Withdraw Collateral',
  borrow:   'Borrow',
  repay:    'Repay Debt',
};

const ACTION_COLOR: Record<ActionType, string> = {
  deposit:  'btn-primary',
  withdraw: 'btn-secondary',
  borrow:   'btn-primary',
  repay:    'btn-secondary',
};

export default function ActionModal({
  open, onClose, onSuccess, action, marketId,
  vaultAddress, debtTokenAddress, sharesBalance, debtBalance,
}: Props) {
  const { address, chainId, isConnected } = useAccount();
  const { engine } = useContractAddresses();
  /** Env `VITE_*` addresses are only valid on this chain — always read balances/allowance here (not the wallet’s current chain). */
  const readChainId = TARGET_CHAIN_ID;
  const chainMismatch = isConnected && chainId != null && chainId !== TARGET_CHAIN_ID;
  const [amount, setAmount] = useState('');
  const [hash, setHash] = useState<Hash | undefined>();
  const [step, setStep] = useState<'input' | 'approving' | 'writing' | 'withdrawn' | 'redeeming' | 'success' | 'error'>('input');
  const [errMsg, setErrMsg] = useState('');

  const { writeContractAsync } = useWriteContract();
  const { isSuccess: confirmed } = useWaitForTransactionReceipt({ hash });

  // Vault share decimals follow the ERC-4626 vault (OZ: same as underlying, e.g. USDC → 6). Debt uses debt token decimals (ceitUSD → 18).
  const { data: vaultDecimalsRead } = useReadContracts({
    contracts: vaultAddress
      ? [{ address: vaultAddress, abi: erc20Abi, functionName: 'decimals' as const, chainId: readChainId }]
      : [],
    query: { enabled: !!vaultAddress },
  });
  const { data: debtDecimalsRead } = useReadContracts({
    contracts: debtTokenAddress
      ? [{ address: debtTokenAddress, abi: erc20Abi, functionName: 'decimals' as const, chainId: readChainId }]
      : [],
    query: { enabled: !!debtTokenAddress },
  });
  const { data: debtSymbolRead } = useReadContracts({
    contracts: debtTokenAddress
      ? [{ address: debtTokenAddress, abi: erc20Abi, functionName: 'symbol' as const, chainId: readChainId }]
      : [],
    query: { enabled: !!debtTokenAddress },
  });
  const shareDecimals = erc20Decimals(vaultDecimalsRead?.[0]?.result as number | bigint | undefined);
  const debtDecimals  = erc20Decimals(debtDecimalsRead?.[0]?.result as number | bigint | undefined);
  const debtSymbol = (debtSymbolRead?.[0]?.result as string | undefined) ?? 'Debt Token';
  const amountDecimals =
    action === 'deposit' || action === 'withdraw' ? shareDecimals : debtDecimals;

  const amountRaw = (() => {
    try { return amount ? parseUnits(amount, amountDecimals) : 0n; } catch { return 0n; }
  })();

  // Read wallet balances: vault shares (for deposit) and debt token (for repay/borrow info)
  const { data: walletData } = useReadContracts({
    contracts: address ? [
      ...(vaultAddress ? [{ address: vaultAddress, abi: erc20Abi, functionName: 'balanceOf' as const, args: [address] as const, chainId: readChainId }] : []),
      ...(debtTokenAddress ? [{ address: debtTokenAddress, abi: erc20Abi, functionName: 'balanceOf' as const, args: [address] as const, chainId: readChainId }] : []),
    ] : [],
    query: { enabled: !!address && (!!vaultAddress || !!debtTokenAddress) },
  });
  const walletShares    = vaultAddress     ? ((walletData?.[0]?.result as bigint | undefined) ?? 0n) : 0n;
  const walletDebtToken = debtTokenAddress ? ((walletData?.[vaultAddress ? 1 : 0]?.result as bigint | undefined) ?? 0n) : 0n;

  // Optional: for withdraw, show underlying asset symbol (assets received after redeem).
  const { data: vaultSymbolData } = useReadContracts({
    contracts: vaultAddress && address ? [{ address: vaultAddress, abi: erc20Abi, functionName: 'symbol' as const, chainId: readChainId }] : [],
    query: { enabled: !!vaultAddress && !!address && action === 'withdraw' },
  });
  const vaultSymbol = (vaultSymbolData?.[0]?.result as string | undefined) ?? 'SHARES';

  const { data: vaultAssetData } = useReadContracts({
    contracts: vaultAddress && address ? [{ address: vaultAddress, abi: erc4626Abi, functionName: 'asset' as const, chainId: readChainId }] : [],
    query: { enabled: !!vaultAddress && !!address && action === 'withdraw' },
  });
  const assetAddress = (vaultAssetData?.[0]?.result as Address | undefined) ?? undefined;

  const { data: assetSymbolData } = useReadContracts({
    contracts: assetAddress && action === 'withdraw' ? [{ address: assetAddress, abi: erc20Abi, functionName: 'symbol' as const, chainId: readChainId }] : [],
    query: { enabled: !!assetAddress && action === 'withdraw' },
  });
  const assetSymbol = (assetSymbolData?.[0]?.result as string | undefined) ?? 'ASSET';

  // Read collateral value for borrow max calculation
  const { data: posValueData } = useReadContracts({
    contracts: engine && address ? [
      { address: engine, abi: ceitnotEngineAbi, functionName: 'getPositionCollateralValue' as const, args: [address, BigInt(marketId)] as const, chainId: readChainId },
    ] : [],
    query: { enabled: !!engine && !!address && action === 'borrow' },
  });
  const collateralValue = (posValueData?.[0]?.result as bigint | undefined) ?? 0n;
  const borrowMaxRaw = (collateralValue * 8000n) / 10000n > (debtBalance ?? 0n)
    ? (collateralValue * 8000n) / 10000n - (debtBalance ?? 0n)
    : 0n;
  const minMeaningfulBorrowRaw = debtDecimals > 6 ? 10n ** BigInt(debtDecimals - 6) : 1n;
  const borrowValueLooksScaledWrong =
    action === 'borrow'
    && collateralValue > 0n
    && borrowMaxRaw > 0n
    && borrowMaxRaw < minMeaningfulBorrowRaw
    && shareDecimals < debtDecimals;
  const borrowDisplayDp = borrowValueLooksScaledWrong ? Math.min(18, debtDecimals) : 6;

  // Check allowance for deposit (vault → engine) or repay (debtToken → engine)
  const approvalToken = action === 'deposit' ? vaultAddress : action === 'repay' ? debtTokenAddress : undefined;
  const { data: allowanceData, refetch: refetchAllowance } = useReadContracts({
    contracts: approvalToken && address && engine ? [{
      address: approvalToken,
      abi: erc20Abi,
      functionName: 'allowance' as const,
      args: [address, engine] as const,
      chainId: readChainId,
    }] : [],
    query: { enabled: !!approvalToken && !!address && !!engine },
  });
  const allowance = (allowanceData?.[0]?.result as bigint | undefined) ?? 0n;
  const needsApproval = (action === 'deposit' || action === 'repay') && amountRaw > 0n && allowance < amountRaw;

  // On confirmed tx
  useEffect(() => {
    if (confirmed && hash) {
      if (step === 'approving') {
        refetchAllowance();
        setStep('input'); // let user proceed to write
      } else if (step === 'writing') {
        if (action === 'withdraw') {
          // After withdrawing shares from the protocol, offer ERC-4626 redeem (shares -> underlying).
          setStep('withdrawn');
        } else {
          setStep('success');
          onSuccess();
        }
      } else if (step === 'redeeming') {
        setStep('success');
        onSuccess();
      }
    }
  }, [confirmed, hash, step, refetchAllowance, onSuccess]);

  const reset = () => { setAmount(''); setHash(undefined); setStep('input'); setErrMsg(''); };
  const close = () => { reset(); onClose(); };

  const setMax = () => {
    if (action === 'deposit'  && walletShares > 0n) setAmount(formatUnits(walletShares, shareDecimals));
    if (action === 'withdraw' && sharesBalance)     setAmount(formatUnits(sharesBalance, shareDecimals));
    if (action === 'repay'    && debtBalance)       setAmount(formatUnits(debtBalance, debtDecimals));
    if (action === 'borrow'   && collateralValue > 0n) {
      if (borrowValueLooksScaledWrong) {
        setAmount('');
        return;
      }
      if (borrowMaxRaw > 0n) setAmount(formatUnits(borrowMaxRaw, debtDecimals));
    }
  };

  async function submit() {
    if (!address || !engine) return;
    if (chainId !== TARGET_CHAIN_ID) {
      setStep('error');
      setErrMsg(
        chainId == null
          ? 'Подключите кошелёк.'
          : `Неверная сеть: сейчас ${chainId}, нужна ${TARGET_CHAIN_ID} (как в настройках приложения).`,
      );
      return;
    }
    const gas = gasFor(chainId);
    try {
      if (needsApproval && approvalToken) {
        setStep('approving');
        const h = await writeContractAsync({
          address: approvalToken,
          abi: erc20Abi,
          functionName: 'approve',
          args: [engine, 2n ** 256n - 1n],
          chainId: TARGET_CHAIN_ID,
          ...gas,
        });
        setHash(h);
        return;
      }

      setStep('writing');
      let h: Hash;
      const writeBase = { chainId: TARGET_CHAIN_ID, ...gas } as const;
      if (action === 'deposit') {
        h = await writeContractAsync({ address: engine, abi: ceitnotEngineAbi, functionName: 'depositCollateral', args: [address, BigInt(marketId), amountRaw], ...writeBase });
      } else if (action === 'withdraw') {
        h = await writeContractAsync({ address: engine, abi: ceitnotEngineAbi, functionName: 'withdrawCollateral', args: [address, BigInt(marketId), amountRaw], ...writeBase });
      } else if (action === 'borrow') {
        h = await writeContractAsync({ address: engine, abi: ceitnotEngineAbi, functionName: 'borrow', args: [address, BigInt(marketId), amountRaw], ...writeBase });
      } else {
        h = await writeContractAsync({ address: engine, abi: ceitnotEngineAbi, functionName: 'repay', args: [address, BigInt(marketId), amountRaw], ...writeBase });
      }
      setHash(h);
    } catch (e: unknown) {
      setStep('error');
      const line = formatWriteContractError(e, ceitnotEngineAbi);
      const hint = hintForEngineError(line);
      setErrMsg(hint ? `${line}\n\n${hint}` : line);
    }
  }

  async function redeemUnderlying() {
    if (!address || !vaultAddress) return;
    if (chainId !== TARGET_CHAIN_ID) return;
    const gas = gasFor(chainId);
    try {
      setStep('redeeming');
      const h = await writeContractAsync({
        address: vaultAddress,
        abi: erc4626Abi,
        functionName: 'redeem',
        // shares -> receiver in underlying; owner=msg.sender (no approve needed)
        args: [amountRaw, address, address],
        chainId: TARGET_CHAIN_ID,
        ...gas,
      });
      setHash(h);
    } catch (e: unknown) {
      setStep('error');
      const line = formatWriteContractError(e, ceitnotEngineAbi);
      const hint = hintForEngineError(line);
      setErrMsg(hint ? `${line}\n\n${hint}` : line);
    }
  }

  if (!open) return null;

  const depositExceedsWallet =
    action === 'deposit' && amountRaw > 0n && amountRaw > walletShares;
  const withdrawExceedsDeposited =
    action === 'withdraw' && sharesBalance !== undefined && amountRaw > sharesBalance;
  const repayExceedsDebt =
    action === 'repay' && debtBalance !== undefined && amountRaw > debtBalance;

  const isPending  = step === 'approving' || step === 'writing' || step === 'redeeming';
  const buttonLabel = step === 'approving'
    ? 'Approving…'
    : step === 'writing'
    ? 'Confirming…'
    : step === 'redeeming'
    ? 'Redeeming…'
    : needsApproval
    ? `Approve ${action === 'deposit' ? vaultSymbol : debtSymbol}`
    : ACTION_LABEL[action];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={close} />

      {/* Modal */}
      <div className="relative z-10 w-full max-w-md card bg-ceitnot-surface border border-ceitnot-border-2 shadow-2xl p-6 animate-fade-in">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold">
            {ACTION_LABEL[action]}
            <span className="ml-2 text-sm text-ceitnot-muted font-normal">Market #{marketId}</span>
          </h2>
          <button onClick={close} className="btn-ghost p-1.5 rounded-lg" aria-label="Close">
            <X size={18} />
          </button>
        </div>

        {/* Success state */}
        {step === 'success' && (
          <div className="text-center py-6">
            <CheckCircle size={48} className="text-ceitnot-success mx-auto mb-3" />
            <p className="font-semibold text-lg">Transaction confirmed!</p>
            <p className="text-ceitnot-muted text-sm mt-1">Your position has been updated.</p>
            <button className="btn-primary mt-6 w-full" onClick={close}>Close</button>
          </div>
        )}

        {/* Error state */}
        {step === 'error' && (
          <div className="text-center py-4">
            <AlertCircle size={40} className="text-ceitnot-danger mx-auto mb-3" />
            <p className="font-semibold text-ceitnot-danger">Transaction failed</p>
            <p className="text-ceitnot-muted text-xs mt-2 break-words whitespace-pre-wrap text-left max-h-48 overflow-y-auto">{errMsg}</p>
            <button className="btn-secondary mt-5 w-full" onClick={() => { setStep('input'); setErrMsg(''); }}>Try again</button>
          </div>
        )}

        {/* Withdraw confirmed -> redeem shares to underlying */}
        {step === 'withdrawn' && (
          <div className="text-center py-6">
            <CheckCircle size={48} className="text-ceitnot-success mx-auto mb-3" />
            <p className="font-semibold text-lg">Withdraw confirmed!</p>
            <p className="text-ceitnot-muted text-sm mt-1">
              Now you have <span className="font-mono">{amount ? amount : '0'}</span> {vaultSymbol} shares.
              Redeem them to get <span className="font-mono">{assetSymbol}</span>.
            </p>
            <button
              className="btn-primary mt-6 w-full"
              onClick={redeemUnderlying}
              disabled={!amountRaw || amountRaw <= 0n || isPending}
            >
              Redeem {vaultSymbol} → {assetSymbol}
            </button>
            <button className="btn-secondary mt-3 w-full" onClick={close} disabled={isPending}>
              Close
            </button>
          </div>
        )}

        {/* Input state */}
        {step !== 'success' && step !== 'error' && step !== 'withdrawn' && (
          <>
            {/* Approve step indicator */}
            {needsApproval && (
              <div className="flex items-center gap-2 mb-4 p-3 bg-ceitnot-warning/10 border border-ceitnot-warning/20 rounded-xl">
                <ArrowRight size={14} className="text-ceitnot-warning shrink-0" />
                <p className="text-xs text-ceitnot-warning">
                  Two steps: first approve the token, then confirm the action.
                </p>
              </div>
            )}

            {/* Amount input */}
            <div className="mb-5">
              <label className="block text-sm text-ceitnot-muted mb-2">
                Amount{' '}
                <span className="text-ceitnot-muted-2">
                  {action === 'deposit' || action === 'withdraw'
                    ? `(vault shares, ${shareDecimals} decimals)`
                    : `(${debtSymbol}, ${debtDecimals} decimals)`}
                </span>
              </label>
              <div className="flex gap-2">
                <input
                  type="number"
                  min="0"
                  value={amount}
                  onChange={e => setAmount(e.target.value)}
                  placeholder="0.0"
                  className="input-field flex-1"
                  disabled={isPending}
                />
                <button
                  type="button"
                  onClick={setMax}
                  className="px-3 py-2 rounded-xl text-sm font-medium bg-ceitnot-gold/15 text-ceitnot-gold hover:bg-ceitnot-gold/25 transition-colors"
                  disabled={isPending}
                >
                  Max
                </button>
              </div>

              {/* Balance hints */}
              {chainMismatch && (
                <p className="text-xs text-ceitnot-danger mt-2">
                  Сеть кошелька ({chainId}) не совпадает с сетью приложения ({TARGET_CHAIN_ID}). Переключите сеть — иначе баланс shares и транзакция расходятся.
                </p>
              )}
            {action === 'deposit' && (
                <p className="text-xs text-ceitnot-muted mt-1">
                  Wallet shares: <span className="text-ceitnot-ink font-mono">{formatUnits(walletShares, shareDecimals)}</span>
                  {depositExceedsWallet && (
                    <span className="block text-ceitnot-danger mt-1">
                      Not enough vault shares — use “Get vault shares” first (mint wstETH → deposit into vault).
                    </span>
                  )}
                </p>
              )}
              {action === 'withdraw' && sharesBalance !== undefined && (
                <p className="text-xs text-ceitnot-muted mt-1">
                  Deposited shares: <span className="text-ceitnot-ink font-mono">{formatUnits(sharesBalance, shareDecimals)}</span>
                </p>
              )}
              {action === 'borrow' && (
                <p className="text-xs text-ceitnot-muted mt-1">
                  Collateral value:{' '}
                  <span className="text-ceitnot-ink font-mono">
                    {formatToken(collateralValue, debtDecimals, borrowDisplayDp, 'en-US')}
                  </span>
                  {' · '}Max borrow (80% LTV):{' '}
                  <span className="text-ceitnot-ink font-mono">
                    {formatToken(borrowMaxRaw, debtDecimals, borrowDisplayDp, 'en-US')}
                  </span>
                  {!!debtBalance && debtBalance > 0n && (
                    <>
                      {' · '}Current debt:{' '}
                      <span className="text-ceitnot-warning font-mono">
                        {formatToken(debtBalance, debtDecimals, 6, 'en-US')}
                      </span>
                    </>
                  )}
                </p>
              )}
              {borrowValueLooksScaledWrong && (
                <p className="text-xs text-ceitnot-warning mt-1">
                  Borrow power is effectively dust for this market. Current max: {formatUnits(borrowMaxRaw, debtDecimals)} {debtSymbol}. This usually indicates market collateral value is returned in a lower decimal scale on-chain; engine upgrade is required to unlock normal borrow size.
                </p>
              )}
              {action === 'repay' && debtBalance !== undefined && debtBalance > 0n && (
                <p className="text-xs text-ceitnot-muted mt-1">
                  Outstanding debt: <span className="text-ceitnot-ink font-mono">{formatUnits(debtBalance, debtDecimals)}</span>
                  {' · '}Wallet {debtSymbol}: <span className="text-ceitnot-ink font-mono">{formatUnits(walletDebtToken, debtDecimals)}</span>
                </p>
              )}
            </div>

            {/* Submit */}
            <button
              type="button"
              onClick={submit}
              disabled={
                isPending
                || chainMismatch
                || !amountRaw
                || amountRaw <= 0n
                || depositExceedsWallet
                || withdrawExceedsDeposited
                || repayExceedsDebt
                || (action === 'borrow' && borrowValueLooksScaledWrong)
              }
              className={`w-full ${ACTION_COLOR[action]} flex items-center justify-center gap-2`}
            >
              {isPending && <Loader2 size={16} className="animate-spin" />}
              {buttonLabel}
            </button>

            {/* Tx hash */}
            {hash && (
              <p className="text-xs text-ceitnot-muted mt-3 text-center font-mono break-all">
                tx: {hash.slice(0, 10)}…{hash.slice(-8)}
              </p>
            )}
          </>
        )}
      </div>
    </div>
  );
}
