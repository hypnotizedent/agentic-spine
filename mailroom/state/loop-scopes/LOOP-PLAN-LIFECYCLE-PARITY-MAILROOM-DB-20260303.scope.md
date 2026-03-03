---
loop_id: LOOP-PLAN-LIFECYCLE-PARITY-MAILROOM-DB-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: plan
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Establish canonical lifecycle contract between plans index and mailroom DB so plan creation/promotion/retire states are transactionally consistent and auto-reconciled.
---

# Loop Scope: LOOP-PLAN-LIFECYCLE-PARITY-MAILROOM-DB-20260303

## Objective

Establish canonical lifecycle contract between plans index and mailroom DB so plan creation/promotion/retire states are transactionally consistent and auto-reconciled.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-PLAN-LIFECYCLE-PARITY-MAILROOM-DB-20260303`

## Phases
- Step 1:  inventory current plan lifecycle surfaces and DB touchpoints
- Step 2:  define authoritative write path and projection contract
- Step 3:  implement reconcile + drift gates + migration receipts

## Success Criteria
- Single authoritative lifecycle source with deterministic projection parity
- No orphan/ghost plan states across YAML and DB

## Definition Of Done
- Lifecycle contract YAML promoted and indexed
- Verify gates pass for lifecycle parity and drift
- Runbook updated with canonical operator path
