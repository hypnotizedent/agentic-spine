---
loop_id: LOOP-EXECUTION-LIFECYCLE-PUBLIC-SERVICE-AUTOPUBLISH-TRANSACTION-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: execution
priority: high
horizon: later
execution_readiness: blocked
blocked_by: "Requires cloudflare.service.publish lifecycle integration — no active execution path until public service onboarding is scheduled"
next_review: "2026-03-15"
objective: Enforce canonical public-service lifecycle transaction so bind/transition/deploy must execute cloudflare.service.publish with evidence, rollback semantics, and drift checks.
---

# Loop Scope: LOOP-EXECUTION-LIFECYCLE-PUBLIC-SERVICE-AUTOPUBLISH-TRANSACTION-20260302

## Objective

Enforce canonical public-service lifecycle transaction so bind/transition/deploy must execute cloudflare.service.publish with evidence, rollback semantics, and drift checks.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-EXECUTION-LIFECYCLE-PUBLIC-SERVICE-AUTOPUBLISH-TRANSACTION-20260302`

## Phases
- W1:  define lifecycle transaction step + contract
- W2:  execute publish during lifecycle transitions
- W3:  assert receipt/evidence on close

## Success Criteria
- Public service lifecycle cannot complete without governed publish evidence
- New service onboarding follows one automatic formula end-to-end

## Definition Of Done
- No manual operator reminder required to publish public routes
