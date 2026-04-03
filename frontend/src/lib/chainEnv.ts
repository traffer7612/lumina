/** Single source for VITE_CHAIN_ID (wagmi + contract reads). */
export const TARGET_CHAIN_ID = Number(import.meta.env.VITE_CHAIN_ID ?? 31337);
