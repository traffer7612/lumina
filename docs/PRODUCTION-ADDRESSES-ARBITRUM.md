# Production contract addresses — Arbitrum One (42161)

Canonical reference for **public** deployments of **Ceitnot Protocol**. Имена в первом столбце — **как в Solidity/эксплорере** (`CeitnotEngine`, …); см. [BRANDING-AND-NAMING.md](BRANDING-AND-NAMING.md).

Keep in sync with `frontend/.env.example` and GitBook after any governance upgrade.

Explorer: [Arbitrum One](https://arbiscan.io/).

## Core protocol (full deploy set)

| Contract | Address |
|----------|---------|
| CeitnotEngine (implementation) | `0xabb9a8986f2ef5abf136f4902fd35e49e37f088e` |
| CeitnotProxy (engine) | `0xd2168f8429acb4796465b07ca6ecf192d9b41619` |
| CeitnotUSD (aUSD) | `0xe1b1a3814c3f5f3cdfd85a63225f7d16ecdd6785` |
| CeitnotMarketRegistry | `0x070b9c6bdbffabefe02de23840069f15eb821c55` |
| CeitnotRouter | `0x4f083ab27345f353e61f04988c8fefc76eacbb7d` |
| CeitnotTreasury | `0xeec09a4ec6fabef4587195296f2d0a4404c7a947` |
| **Legacy PSM (USDC)** | `0xcb18d815e5b686372d9494583812cd46ca869919` |
| CeitnotToken (CEITNOT ticker in UI) | `0xbf6fa2c4d3c31b794417f87d1c06dc401e012e28` |
| VeCeitnot | `0x9617c423dcaaf8d029d4c547747ef020974fcca5` |
| TimelockController | `0x14fae3f4c19a4733ea5762123b8a9131615b2d19` |
| CeitnotGovernor | `0xa4d0f26cabec345034c2687467b6157cae581216` |

## PSM migration (active vs legacy)

| Role | Address | Notes |
|------|---------|--------|
| **Current production PSM (frontend `VITE_PSM_ADDRESS`)** | `0x330c36c9fe280a7d9328165db7ca78e59b119e12` | Deployed with correct pegged-token decimals; admin = Timelock. |
| Legacy PSM | `0xcb18d815e5b686372d9494583812cd46ca869919` | Deprecate after liquidity moved and `CeitnotUSD.removeMinter(legacy)` executed via governance. |

Confirm `CeitnotUSD.minters(newPSM) == true` on Arbiscan after Timelock executes `addMinter`.

## Reference assets (verify script)

Used by verification / test markets; not all are production collateral.

| Item | Address |
|------|---------|
| Mock wstETH (if used) | `0x54eb3b26220eb901349a2dfa5011e89ba62e458b` |
| Mock vault | `0x91799566f1384f5d0ea847aa3720d76faa73caaa` |

## Governance timing

Timelock minimum delay from deploy encoding: **86400** seconds (1 day). Confirm on-chain on the Timelock contract if it was later changed.

## Related docs

- [`TOKENOMICS-PROD-CHECKLIST.md`](TOKENOMICS-PROD-CHECKLIST.md)
- [`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md)
- [`INCIDENT-ROLLBACK-RUNBOOK.md`](INCIDENT-ROLLBACK-RUNBOOK.md)
