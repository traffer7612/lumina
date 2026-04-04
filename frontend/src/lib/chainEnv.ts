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

/** Prefer `primary` env; fall back to `legacy` (e.g. old VITE_AURA_* names after Ceitnot rename). */
export function viteAddressLegacy(primary: string | undefined, legacy: string | undefined): Address | undefined {
  return viteAddress(primary) ?? viteAddress(legacy);
}
