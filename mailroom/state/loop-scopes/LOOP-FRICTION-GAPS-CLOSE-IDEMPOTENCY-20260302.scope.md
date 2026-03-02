---
loop_id: LOOP-FRICTION-GAPS-CLOSE-IDEMPOTENCY-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: low
horizon: later
execution_readiness: runnable
objective: "Make gaps.close idempotent for already-fixed targets to prevent noisy false-failure receipts."
---

# Loop Scope: LOOP-FRICTION-GAPS-CLOSE-IDEMPOTENCY-20260302

## Objective

Make gaps.close idempotent for already-fixed targets to prevent noisy false-failure receipts.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-GAPS-CLOSE-IDEMPOTENCY-20260302`

## Phases
- Step 1: reproduce already-fixed close behavior
- Step 2: implement INFO/skip semantics for idempotent close requests
- Step 3: validate stable receipts and unchanged gap integrity

## Success Criteria
- gaps.close returns deterministic non-error outcome when target is already fixed/closed

## Definition Of Done
- linked gap closed with evidence
- no regression in gap mutation auditability

