---
loop_id: LOOP-FRICTION-AUTHORING-ERGONOMICS-NORMALIZATION-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: low
horizon: later
execution_readiness: runnable
objective: "Reduce authoring trial-and-error in gate/scope workflows by improving vocabulary guidance, schema visibility, and idempotent gap operations."
---

# Loop Scope: LOOP-FRICTION-AUTHORING-ERGONOMICS-NORMALIZATION-20260302

## Objective

Reduce authoring trial-and-error in gate/scope workflows by improving vocabulary guidance, schema visibility, and idempotent gap operations.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-AUTHORING-ERGONOMICS-NORMALIZATION-20260302`

## Phases
- Step 1: document structure/vocabulary hotspots that cause repeated failures
- Step 2: improve guidance and idempotent behavior in authoring paths
- Step 3: validate reduced friction and close linked gaps

## Success Criteria
- D145 errors provide clear alternatives aligned with user language
- gate authoring uses explicit schema/shape references instead of trial-and-error
- `gaps.close` is idempotent for already-fixed targets

## Definition Of Done
- linked gaps fixed with evidence
- authoring flow remains governance compliant

