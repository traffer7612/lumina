# Lumina tokenomics, mint permissions, and fee routing

Companion to [`TOKENOMICS-PROD-CHECKLIST.md`](TOKENOMICS-PROD-CHECKLIST.md). **Numeric token supply, vesting, and treasury balances must be filled by the team** when ready for public disclosure; mechanics below are fixed by code and governance.

## 1. Supply policy (governance + disclosure)

- **LUMINA (governance token, `AuraToken`)**: single `minter` address; inflation only through that minter. **Publish**: intended max supply or emissions schedule, and current `minter` (should be Timelock).
- **aUSD (`AuraUSD`)**: no public mint except through registered **minters**; optional **global debt ceiling** (`globalDebtCeiling`, 0 = unlimited). **Publish**: ceiling value if non-zero, and total supply snapshot for launch comms.

**Action**: Replace TBD rows in your external factsheet with on-chain reads at launch date.

## 2. Mint permission matrix (canonical)

| Asset | Who can mint | Contract path | Admin / control |
|-------|----------------|---------------|-----------------|
| **aUSD** | Registered minters only | `AuraUSD.mint` / `burn` | `addMinter` / `removeMinter` / `transferAdmin` — `AuraUSD.admin` must be Timelock in production. |
| **aUSD via CDP** | `AuraEngine` (proxy) | Engine calls `mint` when user borrows; `burn` on repay/liquidation | Engine is a minter; Engine admin params via timelocked governance. |
| **aUSD via PSM** | `AuraPSM` | `swapIn` mints aUSD; `swapOut` burns | Each PSM deployment must be added as minter via governance. |
| **LUMINA** | Current `AuraToken.minter` | `AuraToken.mint` | `transferMinter` callable only by current minter → route to Timelock. |

**Hidden mint path check**: There is no alternate ERC-20 mint on `AuraUSD` outside `minters`; `AuraToken` has no mint except through `minter`. Verify on Arbiscan: `AuraUSD.admin`, `AuraToken.minter`, and `minters(engine)`, `minters(psm)`.

## 3. Vesting and unlock calendar

**Status**: Document externally with legal cap table (team, investors, advisors, treasury programs). This repo does not store vesting contracts unless you add them; checklist items are satisfied by publishing:

- Cliff and linear unlock dates  
- Monthly unlock amounts post-cliff  
- Addresses holding vesting (EOA vs contract)

## 4. veLUMINA (lock mechanics summary)

From `VeAura` (see also governance UI):

- **Max lock**: 4 years (`MAX_LOCK_DURATION`).  
- **Epoch alignment**: unlock times align to weekly boundaries (`EPOCH`).  
- **Voting power**: decays linearly with remaining lock time (`bias = amount * (unlockTime - now) / MAX_LOCK_DURATION`).  
- **Revenue share**: proportional to **locked amount** (not voting-power decay).  
- **Delegation**: standard `delegate` flow for Governor (IVotes); default self.

## 5. Protocol fee sources (canonical list)

| Source | Mechanism | Typical asset |
|--------|-----------|----------------|
| CDP | Interest / protocol fee parameters on markets | aUSD or configured fee token per deployment |
| PSM | `tinBps` / `toutBps` on swap | Pegged stable (e.g. USDC) held in `feeReserves` |
| Liquidation | Penalty / spread per market params | Per engine configuration |
| Flash loans | `flashFee` if enabled | Per token |

**Single doc rule**: Treat this file + engine/market registry on-chain reads as the source of truth for “what can charge a fee.”

## 6. Fee destinations and accounting cadence

| Stream | Code-level destination | Operational note |
|--------|------------------------|------------------|
| PSM fees | `feeReserves` on PSM; `withdrawFeeReserves` to admin (Timelock) | Publish **who** moves funds to treasury and **how often**. |
| ve revenue | `VeAura.distributeRevenue` (admin-only) pushes reward-per-token; users `claimRevenue` | **Cadence**: each distribution is an on-chain tx; publish intended schedule (e.g. weekly). |
| Treasury / multisig | `AuraTreasury` and governance executors | Publish treasury address policy (see below). |

**TBD for prod comms**: exact percentage split if multiple destinations, buyback/burn if any, and reserves top-up rules.

## 7. Treasury wallet policy (template)

1. **Primary treasury**: document Gnosis Safe (or equivalent) address and signers threshold.  
2. **Spending**: above $X or strategic categories require on-chain proposal through Timelock.  
3. **Operational hot wallet**: if used, cap balance and rotation procedure.  
4. **Monitoring**: subscribe to large outbound transfers (see checklist §8).

## 8. Governance anti-capture (operational)

- **Thresholds**: read from `AuraGovernor` on-chain (`proposalThreshold`, `quorumNumerator`, `votingDelay`, `votingPeriod`).  
- **Expectations**: publish target voter turnout and how the DAO will react to chronic low participation (e.g. parameter reviews, public campaigns).  
- **Emergency**: `pause`, `emergencyShutdown` on engine are high-impact; document who proposes and evidence requirements — see [`INCIDENT-ROLLBACK-RUNBOOK.md`](INCIDENT-ROLLBACK-RUNBOOK.md) and [`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md).

## 9. Treasury composition and runway (disclosure template)

Fill quarterly for investors and checklist §7.

| Category | Examples | Notes |
|----------|-----------|--------|
| Stables | USDC, USDT, DAI | Treasury + PSM operational buffers |
| Volatile / strategic | ETH, LUMINA | Mark-to-market policy |
| LP / protocol-owned liquidity | Pair addresses | IL and unwind rules |
| Monthly burn | Salaries, infra, audits, grants | Round to nearest $1k in public doc |
| Runway | months of burn at current spend | Assumptions stated explicitly |
| Budget buckets | Security, growth, ops, liquidity incentives | % or caps per half-year |

**Discretionary limits**: e.g. multisig can spend up to $N without vote; above requires Governor.

## 10. Fee / treasury monitoring (checklist alignment)

- Tag in block explorer watchlists: `AuraUSD`, engine proxy, active PSM, `VeAura`, `AuraTreasury`, Timelock, Governor.  
- Alert on: `MinterAdded`, `MinterRemoved`, `AdminTransferred`, large `Transfer` from PSM/treasury, `Paused`, governance `ProposalExecuted` to protocol addresses.
