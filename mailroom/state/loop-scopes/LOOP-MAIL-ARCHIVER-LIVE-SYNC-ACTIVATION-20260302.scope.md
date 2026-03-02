---
loop_id: LOOP-MAIL-ARCHIVER-LIVE-SYNC-ACTIVATION-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: mail
priority: high
horizon: now
execution_readiness: runnable
objective: Activate Gmail live-sync end-to-end on VM214 using governed secrets flow; formally classify Microsoft live-sync path and close/park with evidence
---

# Loop Scope: LOOP-MAIL-ARCHIVER-LIVE-SYNC-ACTIVATION-20260302

## Objective

Activate Gmail live-sync end-to-end on VM214 using governed secrets flow; formally classify Microsoft live-sync path and close/park with evidence

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAIL-ARCHIVER-LIVE-SYNC-ACTIVATION-20260302`

## Phases
- Step 1:  baseline and credential discovery
- Step 2:  Gmail live-sync activation
- Step 3:  Microsoft live-sync feasibility decision
- Step 4:  verify backup/freshness parity and closeout

## Success Criteria
- Gmail lane is live-sync with current LastSync evidence
- No secret values are printed in logs/receipts
- Communications and backup verify packs pass or pre-existing blockers are classified

## Definition Of Done
- Loop scope committed and pushed
- Runbook/authority updated only if runtime truth changed
