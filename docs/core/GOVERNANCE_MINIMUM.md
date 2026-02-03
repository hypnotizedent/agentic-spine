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

<!-- SPINE_RULE_API_PRECONDITIONS -->
## API capability preconditions (locked rule)

Any capability that touches an external API **must**:

1. Declare and enforce these preconditions (STOP=2 if missing):
   - `secrets.binding`
   - `secrets.auth.status`

2. Be runnable **only** via the spine front door:
   - `./bin/ops cap run <cap> [args...]`
   Direct script invocation is non-canonical.

3. Never print secret values. (Only presence/absence and counts are allowed.)

Rationale: This prevents drift, avoids "where are secrets?" regressions, and makes every API action reproducible with admissible receipts.
