# Governance: How It Works

This guide explains governance flow for new users in simple terms.

## 1) Get LUMINA

Users first need `LUMINA` tokens. Sources can include:

- public sale (for example, GemPad),
- community distribution or airdrop,
- ecosystem incentives.

## 2) Lock LUMINA to receive veLUMINA

`veLUMINA` is not bought directly.  
It is minted from locked `LUMINA`.

- Lock amount + lock duration are selected on the Governance page.
- Longer lock means stronger long-term commitment.
- Only `veLUMINA` gives governance voting power.

## 3) Earn protocol revenue

While a user has an active lock, they can accrue protocol revenue.

- The UI displays this as `Pending Revenue`.
- Users can claim it with `Claim Revenue`.
- This aligns users toward long-term participation.

## 4) Participate in production governance

The protocol uses on-chain governance with `Governor + Timelock`.

Flow:

1. `Create Proposal`  
2. `Vote`  
3. `Queue`  
4. `Execute`

This means approved changes are not instant; they pass through governance process and timelock delay.

## 5) Current parameters (example)

- `Voting Delay`: 86400 (1 day)
- `Voting Period`: 604800 (7 days)
- `Proposal Threshold`: 100000 veLUMINA
- `Quorum`: dynamic, based on current governance supply

## 6) Important operational rules

- Keep proposal description and calldata consistent across `create/queue/execute`.
- Vote only when proposal state is `Active`.
- Execute only after proposal is successfully queued and timelock delay has passed.
