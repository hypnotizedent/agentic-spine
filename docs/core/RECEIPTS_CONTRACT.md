# Receipts Contract (Authoritative)

> **Status:** authoritative
> **Last verified:** 2026-02-07

A receipt is the admissible proof artifact for governed runtime work.

## Canonical Location
`receipts/sessions/R<RUN_KEY>/receipt.md`

`RUN_KEY` is the single runtime identity:
- Watcher/mailroom runs: queued prompt filename stem.
- Capability runs: `CAP-<timestamp>__<capability>__R<id>`.

## Active Receipt Profiles

### 1) Watcher Receipt (`ops run` / inbox watcher)
Expected invariants:
- Receipt path: `receipts/sessions/R<run_key>/receipt.md`
- Outbox result exists: `mailroom/outbox/<run_key>__RESULT.md`
- Latest ledger row for `run_id=<run_key>` is terminal (`done|failed|parked`)
- Receipt includes status, generated timestamp, input/output hashes, and error section

### 2) Capability Receipt (`ops cap run`)
Expected invariants:
- Receipt path: `receipts/sessions/R<CAP-run_key>/receipt.md`
- Receipt directory includes `output.txt`
- Latest ledger row for `run_id=<CAP-run_key>` is terminal (`done|failed`)
- Receipt includes capability name, status/exit code, command, cwd, args, and timestamps

## Proof Rule
If there is no receipt at the canonical location, the run is not admissible proof.

## Discovery

Receipts are discoverable by filesystem walk over the canonical path:

```bash
# List all receipts (most recent first)
find receipts/sessions -name receipt.md -type f | sort -r | head -20

# Count total receipts
find receipts/sessions -name receipt.md -type f | wc -l

# Find receipts for a specific capability
find receipts/sessions -path '*__<capability>__*' -name receipt.md

# Reconcile ledger done entries against receipts
# (full script in docs/governance/MAILROOM_RUNBOOK.md § Reconciling Ledger with Receipts)
```

The ledger (`mailroom/state/ledger.csv`) maps `run_id` to status and timestamps, but is
a transaction log — not a receipt index. To resolve a `run_id` to its receipt:
`receipts/sessions/R<run_id>/receipt.md`.

No materialized index file exists by design — receipts are immutable write-once artifacts
and the canonical path structure is the index. The `verify.drift_gates.failure_stats`
capability demonstrates programmatic receipt scanning for analysis.

## Historical Note
Legacy historical folders may contain auxiliary artifacts without `receipt.md`. Those are historical debt and not part of current runtime compliance.
