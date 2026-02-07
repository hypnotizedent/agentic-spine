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

## Historical Note
Legacy historical folders may contain auxiliary artifacts without `receipt.md`. Those are historical debt and not part of current runtime compliance.
