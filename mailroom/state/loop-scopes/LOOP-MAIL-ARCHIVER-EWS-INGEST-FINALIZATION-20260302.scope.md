---
loop_id: LOOP-MAIL-ARCHIVER-EWS-INGEST-FINALIZATION-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: mail
priority: high
horizon: now
execution_readiness: blocked
objective: Track long-running Microsoft EWS archive ingest completion, reconcile imported counts/sizes/freshness, finalize mail-archiver backup parity, and close or reclassify GAP-OP-973 with receipts once import is complete.
---

# Loop Scope: LOOP-MAIL-ARCHIVER-EWS-INGEST-FINALIZATION-20260302

## Objective

Track long-running Microsoft EWS archive ingest completion, reconcile imported counts/sizes/freshness, finalize mail-archiver backup parity, and close or reclassify GAP-OP-973 with receipts once import is complete.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAIL-ARCHIVER-EWS-INGEST-FINALIZATION-20260302`

## Phases
- W1:  Monitor active ingest progress + checkpoint evidence
- W2:  Post-ingest count/size/freshness reconciliation per account
- W3:  Backup parity validation + restore drill evidence for mail-archiver
- W4:  GAP-OP-973 disposition and loop closeout

## Success Criteria
- Ingest completion evidence with deterministic totals
- All account linkage + freshness fields reflect runtime truth
- Mail-archiver backups verified and governed

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
