# PSM policy, oracle response, and market risk

Operational policies referenced from [`TOKENOMICS-PROD-CHECKLIST.md`](TOKENOMICS-PROD-CHECKLIST.md).

## 1. PSM economic parameters

- **tin / tout**: Basis-point fees on swap in/out (`AuraPSM`). Governance can adjust within bounds you define off-chain (publish max allowed Bps for operator safety).  
- **Ceiling**: `ceiling` caps net aUSD minted via this PSM (`mintedViaPsm`). 0 = unlimited — document if you rely on a finite ceiling for risk.  
- **Pegged token**: Decimals are fixed at deploy; changing collateral requires a **new PSM deployment** + minter migration.

**Production**: Keep [`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md) updated when `VITE_PSM_ADDRESS` changes.

## 2. PSM liquidity policy

| Topic | Policy (fill operational numbers) |
|-------|-----------------------------------|
| Minimum reserves | Target minimum USDC/DAI/USDT balance in PSM for `swapOut` depth |
| Refill | Who sends stablecoin to PSM, from which treasury wallet, SLA |
| Drain | `withdrawLiquidity` removes **non-fee** liquidity for migration; fees stay in `feeReserves` until `withdrawFeeReserves` |

## 3. Incident: accidental transfers / rescue

- **User sends wrong token to PSM**: PSM only handles `peggedToken` and aUSD in defined flows; random ERC-20 may be stuck with **no** generic rescue in core PSM — treat as **non-custodial loss** unless a governance-approved rescue contract is deployed.  
- **aUSD/USDC stuck due to UI bug**: pause frontend feature, communicate, fix; on-chain state may require governance intervention only if contracts allow.  
- **Document**: public disclaimer that only intended swap paths are supported.

## 4. Oracle per market

For each live market, publish (and store in internal runbook):

- Feed contract address  
- Heartbeat / deviation expectations (Chainlink-style)  
- Whether the relay allows stale reads or enforces `latestRound` freshness (see deployed `OracleRelay` settings)

## 5. Stale price and pause conditions

| Condition | Response |
|-----------|----------|
| Feed heartbeat exceeded | Pause new borrows / liquidations per governance playbook; communicate. |
| Extreme deviation vs reference | Investigation; consider engine `pause` via Timelock proposal. |
| Oracle compromise suspected | Emergency governance path; prepare multisig contacts — [`INCIDENT-ROLLBACK-RUNBOOK.md`](INCIDENT-ROLLBACK-RUNBOOK.md). |

**Slippage / liquidation**: Publish assumptions for liquidator bots (min DEX depth, max price impact) per collateral.

## 6. Market parameter table

**Authoritative values** are on-chain (`AuraMarketRegistry` + engine reads). Maintain a **public table** (GitBook or this repo) with columns:

- Market id, collateral vault, LTV, liquidation threshold, liquidation penalty, debt ceiling, oracle feed

Regenerate after each `addMarket` or param change proposal.

## 7. Delisting / freeze / emergency shutdown

| Action | Path |
|--------|------|
| **Freeze single market** | Governance sets restrictive params or pauses specific market flows per engine capabilities — document exact function names per deployment. |
| **Global pause** | `AuraEngine.pause()` (Timelock) — stops state-changing ops until `unpause`. |
| **Emergency shutdown** | `emergencyShutdown()` — **irreversible** in typical deployment; only for catastrophic scenarios with legal/comms plan. |
| **PSM-only issue** | Increase fees to disincentivize flow, or migrate to new PSM + `removeMinter(old)` after liquidity drained. |

Record proposal IDs and execution txs in [`TOKENOMICS-PROD-CHECKLIST.md`](TOKENOMICS-PROD-CHECKLIST.md) Evidence Log.

## 8. Risk update process

1. Draft parameter change with risk memo (volatility, liquidity, oracle quality).  
2. Forum / Discord review window.  
3. On-chain proposal + Timelock delay.  
4. Post-execution verification script or UI smoke.  
5. Rollback: reverse parameter proposal if design allows; otherwise migration plan.
