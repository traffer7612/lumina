# Investor Governance Overview

## Short Version

Lumina governance is designed to reduce unilateral control risk and make protocol changes transparent, reviewable, and delayed before execution.

## Governance Stack

- `veLUMINA` as voting power (obtained by locking LUMINA),
- `AuraGovernor` for proposal lifecycle and voting,
- `Timelock` for delayed execution of approved actions,
- on-chain execution into core protocol contracts.

## Why this matters for investors

1. **No instant admin changes**  
   Critical changes should pass through proposal, vote, queue, and execute steps.

2. **Transparent decision trail**  
   Governance actions are publicly observable on-chain.

3. **Time to react**  
   Timelock delay creates a reaction window before approved changes are executed.

4. **Aligned incentives**  
   Voting power is tied to locked token participation, encouraging long-term behavior.

## Operational model

Users:
- acquire LUMINA,
- lock LUMINA to receive veLUMINA,
- vote and optionally delegate,
- earn protocol revenue as long-term participants.

Governance actions:
- create proposal,
- vote,
- queue into timelock,
- execute on-chain.

## Risk controls expected by institutional participants

- multisig and/or timelock custody for privileged paths,
- audited governance and core contract logic,
- defined proposal standards and emergency policy,
- public monitoring of admin and governance transactions.

## Production Readiness Checklist

For launch readiness across governance, tokenomics, treasury policy, risk limits, and public transparency, see:

- `docs/TOKENOMICS-PROD-CHECKLIST.md`
