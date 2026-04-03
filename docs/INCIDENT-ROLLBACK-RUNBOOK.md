# Incident response and rollback — first 24 hours

Goal: **contain damage**, **communicate**, **restore safe operation** without guessing on-chain. Pair with [`PSM-ORACLE-MARKET-RISK.md`](PSM-ORACLE-MARKET-RISK.md).

## Roles (fill names / handles)

| Role | Responsibility |
|------|----------------|
| Incident lead | Coordinates comms and decisions |
| Smart contract signer(s) | Timelock / multisig execution |
| Frontend owner | Vercel rollback, env toggles, maintenance banner |
| Comms | Twitter / Discord / support |

## Hour 0–1: triage

1. **Classify**: oracle / PSM / engine / UI-only / key compromise.  
2. **Stop bleeding**: if UI is wrong, add maintenance mode or rollback deployment (Vercel → previous production deployment).  
3. **Preserve evidence**: tx hashes, block numbers, screenshots, affected addresses.

## Hour 1–8: on-chain containment (if protocol-level)

| Situation | Levers |
|-----------|--------|
| Active exploit or bad parameter | Prepare Timelock proposal for `pause` or param fix; multisig emergency if allowed by governance setup |
| Oracle stale / manipulated | Pause new risky operations; coordinate with liquidations |
| PSM bank run risk | Comms on reserves; prepare liquidity; adjust fees only via governance if time permits |

**Do not** execute irreversible actions (`emergencyShutdown`) without legal + incident lead sign-off.

## Hour 8–24: rollback and verification

1. **Frontend**: revert to last known-good Git tag + env file; confirm `VITE_PSM_ADDRESS` and engine proxy match [`PRODUCTION-ADDRESSES-ARBITRUM.md`](PRODUCTION-ADDRESSES-ARBITRUM.md).  
2. **Contracts**: after Timelock executes fix, run smoke: connect wallet, read-only market list, one small swap on staging fork if available.  
3. **Postmortem**: timeline, root cause, corrective actions; link txs in Evidence Log.

## Communication template (short)

- What users should **stop** doing (if anything)  
- What remains **safe**  
- Where to track updates (Discord / Twitter)  
- No speculation on losses until confirmed

## Checklist reference

Maps to `TOKENOMICS-PROD-CHECKLIST.md` §10 (smoke tests) and §8 (monitoring): after any incident, re-run smoke tests and update monitoring rules.
