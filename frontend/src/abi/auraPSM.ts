// ─── AuraPSM ABI ──────────────────────────────────────────────────────────────
export const auraPsmAbi = [
  // Read
  { inputs: [], name: 'ausd', outputs: [{ name: '', type: 'address' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'peggedToken', outputs: [{ name: '', type: 'address' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'peggedDecimals', outputs: [{ name: '', type: 'uint8' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'tinBps', outputs: [{ name: '', type: 'uint16' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'toutBps', outputs: [{ name: '', type: 'uint16' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'ceiling', outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'mintedViaPsm', outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'feeReserves', outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'availableReserves', outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view', type: 'function' },
  { inputs: [], name: 'admin', outputs: [{ name: '', type: 'address' }], stateMutability: 'view', type: 'function' },
  // Write
  { inputs: [{ name: 'amount', type: 'uint256' }], name: 'swapIn', outputs: [{ name: 'ausdOut', type: 'uint256' }], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: 'amount', type: 'uint256' }], name: 'swapOut', outputs: [{ name: 'stableOut', type: 'uint256' }], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }], name: 'withdrawFeeReserves', outputs: [], stateMutability: 'nonpayable', type: 'function' },
  { inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }], name: 'withdrawLiquidity', outputs: [], stateMutability: 'nonpayable', type: 'function' },
] as const;
