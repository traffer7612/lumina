# Changelog — Ceitnot Protocol

Все изменения по фазам разработки. В списках ниже **CeitnotRouter**, **CeitnotEngine** и т.п. — **имена смарт-контрактов** в репозитории; публичный бренд — **Ceitnot** ([BRANDING-AND-NAMING.md](BRANDING-AND-NAMING.md)).

---

## Phase 10 — DX & Composability
- **CeitnotRouter** — stateless маршрутизатор: `depositCollateral`, `depositAndBorrow`, `repayAndWithdraw`, `leverageUp/Down` + EIP-2612 permit flows
- **Delegate system** — `setDelegate(address, bool)` в CeitnotEngine: позволяет внешним контрактам (Router) действовать от имени пользователя
- **Multicall** — батч-вызовы через `delegatecall` для атомарных admin-операций
- **EIP-2612 permit** — gasless approve для vault tokens и aUSD через Router

## Phase 9 — CDP Mode & PSM
- **CeitnotUSD** — mintable стейблкоин: minter management, global debt ceiling, EIP-2612 permit, custom ERC-20 (без OZ зависимости)
- **CDP mode** в CeitnotEngine — `borrow` минтит aUSD (вместо transfer USDC), `repay`/`liquidate` сжигают aUSD, per-market debt ceiling
- **CeitnotPSM** — Peg Stability Module: 1:1 свопы aUSD ↔ pegged stable (USDC/DAI), настраиваемые комиссии tin/tout, ceiling, fee reserves

## Phase 8 — Oracle V2
- **OracleRelayV2** — multi-source median oracle (до 8 feeds), circuit breaker (maxDeviationBps), L2 sequencer uptime feed с grace period
- Per-market oracle: каждый рынок указывает на свой OracleRelayV2

## Phase 7 — Governance
- **CeitnotToken** — ERC-20 + ERC20Votes, timestamp-based clock (EIP-6372)
- **VeCeitnot** — Vote-Escrow: lock governance token (до 4 лет), линейное затухание voting power, delegation, revenue distribution (reward-per-token)
- **CeitnotGovernor** — OpenZeppelin Governor + TimelockControl + VotesQuorumFraction
- **CeitnotTreasury** — казначейство: deposit, withdraw, batch distribute

## Phase 6 — Advanced Liquidation
- **Dutch-аукцион** — линейный рост эффективного penalty от 0 до `liquidationPenaltyBps` за `auctionDuration` (после `initiateLiquidation`)
- **Close factor** — максимальная доля долга для ликвидации за раз (closeFactorBps)
- **Protocol liquidation fee** — часть seized коллатерала идёт в протокол
- **Full liquidation threshold** — ниже порога разрешается полная ликвидация

## Phase 5 — Yield & Fees
- **Harvest yield** — автоматическое применение дохода от коллатерала к долгу через `globalDebtScale`
- **Yield fee** — протокол забирает % от yield (yieldFeeBps)
- **Origination fee** — комиссия при займе (originationFeeBps)
- **Reserve factor** — часть начисленных процентов идёт в reserves протокола
- **Flash-loan reserves** — отдельные reserves от flash-loan комиссий

## Phase 4 — Interest Rate Model
- **Kink-based IRM** — `baseRate + slope1 × min(u, kink) + slope2 × max(0, u − kink)`
- Per-market IRM параметры через MarketRegistry
- Автоматическое начисление процентов через `borrowIndex` (RAY precision)
- Reserve factor: часть начисленных процентов → протокол

## Phase 3 — Multi-Market & Isolation
- **CeitnotMarketRegistry** — standalone реестр рынков
- Multi-market: пользователь может иметь позиции в нескольких рынках
- **Isolation mode** — изолированные рынки с отдельным borrowCap
- Supply/borrow caps per market
- Freeze/deactivate market

## Phase 2 — Security & Admin
- **Timelock** — все критические параметры (LTV, liquidation threshold/penalty) через timelock
- **Pause / Unpause** — остановка всех мутирующих операций
- **Emergency shutdown** — необратимое отключение (только withdrawCollateral разрешён)
- **Same-block guard** — защита от flash-loan манипуляций (noSameBlock modifier)
- **Flash loans** — ERC-3156 с configurable fee

## Phase 1 — Core
- **CeitnotEngine** — deposit/withdraw collateral, borrow/repay
- **CeitnotProxy** — UUPS proxy (EIP-1822) с EIP-1967 storage slot
- **CeitnotStorage** — EIP-7201 namespaced storage
- **OracleRelay** — Chainlink primary + fallback, staleness check, TWAP
- **FixedPoint** — WAD/RAY математика
- **CeitnotVault4626** — ERC-4626 view adapter

---

## Security Fixes (post-Slither audit)
- **CeitnotRouter**: проверка return value `transferFrom`/`approve` (8 мест) + error `Router__TransferFailed`
- **CeitnotPSM**: CEI pattern в `swapIn`/`swapOut` — state updates до external calls
- **VeCeitnot**: CEI pattern в `lock`/`increaseAmount`/`distributeRevenue` — `_transferIn` после state updates
- **CeitnotMarketRegistry**: zero-address check в `setEngine()`
- **CeitnotProxy**: zero-address check в конструкторе (`Proxy__ZeroImplementation`)
- **CeitnotVault4626**: zero-address check в конструкторе (`Vault4626__ZeroAddress`)
- **OracleRelay**: zero-address check для `primaryFeed` (`OracleRelay__ZeroPrimaryFeed`)
- **VeCeitnot**: zero-address check в `setRevenueToken()`

---

## Testing
- **296 тестов**: юнит (66), security (60), flash-loan (19), governance (23), Phase9 (25), Phase10 (24), OracleV2 (40), fuzz (8×1000), invariants (5×256×50), gas benchmarks (6), slot (1), treasury (19)
- **Slither v0.11.3**: 264 findings → все High/Medium исправлены; Low/Info — принятые паттерны
- **0 critical vulnerabilities**
