# Governance Minimum (Portable Invariants)

This is the smallest governance set required for the spine to remain regression-proof.

## Core invariants
- No work outside governed runtime
- No results without receipts
- No new capability without allowlist
- No behavior change without fixtures + replay determinism
- If verify fails, it does not ship

## Drift rules
- No HOME drift roots (~/agent, ~/runs, ~/log, ~/logs must not exist)
- No competing launchd/cron runtimes outside the spine

## Proof rules
- Proof must be watcher+ops produced
- Admissible receipts live under receipts/sessions
