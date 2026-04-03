# Tokenomics & Go-Live Checklist (Production)

Use this document as a release gate before public production rollout.
Mark each item as done with evidence (proposal link, tx hash, dashboard screenshot, or doc PR).

Status legend:
- `🟢` done
- `🟡` in progress / partially done
- `🔴` missing

## 1) Token Supply & Emissions

- 🟡 Define maximum supply policy (hard cap or governed inflation path). (mechanics in [`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md); **publish numbers**)
- 🟡 Document initial circulating supply and fully diluted supply assumptions. (same — **fill at launch**)
- 🟢 Document all mint roles and mint permissions (who can mint, through which contract path). ([`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md) §2)
- 🟡 Publish vesting schedules (team, advisors, investors, treasury programs). (off-chain cap table; template pointers in §3 of same doc)
- 🟡 Publish unlock calendar with dates and monthly unlock amounts. (same)
- 🟡 Confirm no hidden mint path exists outside documented governance flow. (verification steps in [`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md) §2 — **run before mainnet comms**)

## 2) veToken / Governance Incentives

- 🟡 Publish lock mechanics (min/max lock, weight curve, reset behavior). (partially documented in governance docs/UI)
- 🟡 Publish delegation model and expected voter behavior. (delegation exists in UI; policy text can be improved)
- 🟢 Publish governance thresholds: proposal threshold, quorum, voting delay/period. (on-chain + UI visible)
- 🟡 Publish governance anti-capture policy (turnout expectations, emergency response). ([`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md) §8 — **add targets**)
- 🟡 Verify thresholds are realistic for current ve supply and participation. (on-chain read + community review)

## 3) Revenue & Fee Flow

- 🟢 Publish protocol fee sources (CDP, PSM, liquidation, other). ([`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md) §5)
- 🟡 Publish destination of each fee stream (treasury, ve rewards, reserves, buyback). ([§6](LUMINA-TOKENOMICS-AND-FEES.md) — **confirm %/routing**)
- 🟡 Publish accounting cadence (how often distribution/claim updates happen). ([§6](LUMINA-TOKENOMICS-AND-FEES.md) — **state schedule**)
- 🟡 Publish treasury wallet policy and spending authorization path. ([§7](LUMINA-TOKENOMICS-AND-FEES.md) — **fill addresses/rules**)
- 🟡 Add monitoring for fee inflow/outflow addresses. ([§10](LUMINA-TOKENOMICS-AND-FEES.md) — **configure alerts**)

## 4) PSM Economic Parameters

- 🟡 Finalize and publish `tin` / `tout` policy and allowed governance range. ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §1 — **set max Bps**)
- 🟢 Confirm active production PSM address and deprecate legacy PSM in docs. ([`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md) migration table)
- 🟡 Confirm `AuraUSD.addMinter(newPSM)` execution status. (queue/execute Timelock when ready; verify `minters` on aUSD)
- 🟡 Plan and execute `removeMinter(oldPSM)` when migration is complete. (governance proposal after liquidity moved)
- 🟡 Publish PSM liquidity policy (minimum reserves, refill procedure, responsible role). ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §2 — **fill numbers**)
- 🟡 Publish incident policy for accidental transfers / rescue logic. ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §3)

## 5) Market Risk Framework

- 🟡 For every live market publish: LTV, liquidation threshold, penalty, caps, debt ceiling. ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §6 — **paste on-chain table**)
- 🟡 Explain rationale for each parameter set (volatility, liquidity, oracle quality). (risk memo per market — template in §8)
- 🟢 Define risk update process (proposal template, review, approval, rollback). ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §8)
- 🟡 Define onboarding checklist for each new collateral market. (partial guides exist)
- 🟢 Define delisting / freeze / emergency shutdown decision path. ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §7)

## 6) Oracle & Liquidity Assumptions

- 🟡 Publish oracle source per market (feed address, heartbeat, fallback behavior). ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §4 — **complete per market**)
- 🟡 Publish stale-price response policy and pause conditions. ([§5](PSM-ORACLE-MARKET-RISK.md))
- 🟡 Publish minimum DEX/CEX liquidity expectations per collateral/token. ([§5](PSM-ORACLE-MARKET-RISK.md) — **fill thresholds**)
- 🟡 Publish slippage and liquidation execution assumptions. ([§5](PSM-ORACLE-MARKET-RISK.md) — **fill**)

## 7) Treasury & Runway

- 🟡 Publish treasury composition (stable, volatile, LP, protocol-owned assets). ([`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md) §9 template)
- 🟡 Publish monthly burn and runway estimate. (same)
- 🟡 Publish budget categories (security, growth, operations, liquidity incentives). (same)
- 🟡 Publish discretionary spending limits and governance approval rules. (same + §7 treasury policy)

## 8) Security, Controls, and Ops

- 🟡 Confirm all privileged roles are timelock/governance controlled in production. (core path mostly migrated; verify all contracts)
- 🟡 Confirm emergency roles and powers are documented and monitored. ([`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md) §7 + [`INCIDENT-ROLLBACK-RUNBOOK.md`](INCIDENT-ROLLBACK-RUNBOOK.md) — **assign people**)
- 🟡 Confirm audit status for core contracts and key post-audit changes. (security docs exist; final post-fix audit status pending)
- 🟡 Confirm bug bounty scope and payout policy is public. (`docs/BUG-BOUNTY.md` exists; validate coverage and amounts)
- 🟡 Confirm on-chain alerts (role changes, minter changes, pauses, large outflows). ([`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md) §10 — **enable tooling**)

## 9) Frontend & Public Transparency

- 🟢 Governance page shows recent proposals and governance activity clearly.
- 🟢 Proposal descriptions are human-readable (not only raw ids/calldata).
- 🟢 Public docs include current production addresses and chain IDs. ([`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md) + `frontend/.env.example`)
- 🟢 Explorer links for proposal, vote, queue, execute are easy to access.
- 🟢 Public docs include migration status (legacy contracts vs active contracts). ([`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md) PSM migration)

## 10) Vercel / Public Launch Gate

- 🟡 Production env values validated (all contract addresses and chain IDs). (needs final prod verification pass)
- 🟢 New PSM address is set and verified in frontend env.
- 🔴 Smoke test complete on public deployment:
  - 🟡 Connect wallet
  - 🟡 View market list
  - 🟡 Governance proposal view
  - 🟡 Vote flow (where eligible)
  - 🔴 Swap quote and execution path
- 🟡 Incident rollback plan documented (who does what within first 24h). ([`INCIDENT-ROLLBACK-RUNBOOK.md`](INCIDENT-ROLLBACK-RUNBOOK.md) — **fill roles**)

## Evidence Log (fill during rollout)

- Proposal links: *(Governor on Arbiscan + optional `VITE_TALLY_URL`)*
- Execute tx hashes: *(Timelock `execute` txs)*
- Role/minter change tx hashes: *e.g. `AuraUSD.addMinter(new PSM)` after queue; later `removeMinter(legacy PSM)`*
- Final market parameter proposal IDs:
- Public docs PR links: *this checklist + [`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md), [`LUMINA-TOKENOMICS-AND-FEES.md`](LUMINA-TOKENOMICS-AND-FEES.md), [`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md), [`INCIDENT-ROLLBACK-RUNBOOK.md`](INCIDENT-ROLLBACK-RUNBOOK.md)*

