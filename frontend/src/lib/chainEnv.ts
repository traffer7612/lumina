import { isAddress, type Address } from 'viem';

/** Single source for VITE_CHAIN_ID (wagmi + contract reads). */
export const TARGET_CHAIN_ID = Number(import.meta.env.VITE_CHAIN_ID ?? 31337);

/**
 * Safe address from Vite env: trim whitespace; reject empty / invalid strings.
 * Prevents wagmi/viem from throwing when .env has typos, quotes, or placeholders.
 */
export function viteAddress(raw: string | undefined): Address | undefined {
  const v = typeof raw === 'string' ? raw.trim() : '';
  if (!v || !isAddress(v)) return undefined;
  return v as Address;
}

/** Prefer `primary` env; fall back to a secondary alias during address migrations. */
export function viteAddressLegacy(primary: string | undefined, legacy: string | undefined): Address | undefined {
  return viteAddress(primary) ?? viteAddress(legacy);
}

/**
 * Comma-separated market IDs to hide from dashboard / markets list / market picker (e.g. legacy broken oracle on testnet).
 * Users who still have collateral in a hidden market will still see that market in the picker and position cards.
 */
export function hiddenMarketIds(): Set<number> {
  const raw = import.meta.env.VITE_HIDDEN_MARKET_IDS;
  if (typeof raw !== 'string' || !raw.trim()) return new Set();
  return new Set(
    raw
      .split(',')
      .map(s => parseInt(s.trim(), 10))
      .filter(n => Number.isFinite(n) && n >= 0),
  );
}
