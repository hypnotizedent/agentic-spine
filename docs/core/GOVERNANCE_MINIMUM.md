# Governance Minimum (Portable Invariants)

> **Status:** authoritative
> **Last verified:** 2026-02-13

This is the smallest governance set required for the spine to remain regression-proof.

## Disposition

**Standalone by design.** This document is intentionally separate from CORE_LOCK.md.
CORE_LOCK defines the runtime model, entry points, and drift gates. GOVERNANCE_MINIMUM
defines the portable invariants that hold even without the full spine runtime (e.g., during
bootstrap or disaster recovery). Do not merge these two documents.

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
