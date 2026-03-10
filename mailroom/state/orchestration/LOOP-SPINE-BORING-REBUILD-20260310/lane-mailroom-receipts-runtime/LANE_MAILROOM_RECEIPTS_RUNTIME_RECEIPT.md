# Lane Mailroom Receipts Runtime Receipt

**Loop:** `LOOP-SPINE-BORING-REBUILD-20260310`
**Lane:** `lane-mailroom-receipts-runtime`
**Scope:** `mailroom/`, `receipts/`, `runtime/`

## Produced

- `MAILROOM_SCORECARD.md`
- `MAILROOM_STATE_SCORECARD.md`
- `RECEIPTS_SCORECARD.md`
- `RUNTIME_SCORECARD.md`
- `MAILROOM_QUALIFICATION_MANIFEST.tsv`
- `RECEIPTS_QUALIFICATION_MANIFEST.tsv`
- `RUNTIME_QUALIFICATION_MANIFEST.tsv`
- `MAILROOM_RUNTIME_EXTRACTION_BOUNDARY_MAP.md`
- `RECEIPTS_EVIDENCE_BOUNDARY_MAP.md`

## Findings

- `receipts/` is uniformly evidence-only and should leave the spine repo.
- `runtime/` is uniformly runtime-only and should leave the spine repo.
- `mailroom/` is the main mixed zone: active loop/plans/orchestration and a few declarative state files are still governance source, while queue lanes, logs, pids, locks, sessions, ledgers, tokens, and most outbox/state exhaust are runtime or evidence.

