---
loop_id: LOOP-FRICTION-SESSION-ROLE-OVERRIDE-ERGONOMICS-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: medium
horizon: later
execution_readiness: runnable
objective: "Reduce session.start and role-override ceremony by normalizing runtime role handling and override persistence."
---

# Loop Scope: LOOP-FRICTION-SESSION-ROLE-OVERRIDE-ERGONOMICS-20260302

## Objective

Reduce session.start and role-override ceremony by normalizing runtime role handling and override persistence.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-SESSION-ROLE-OVERRIDE-ERGONOMICS-20260302`

## Phases
- Step 1: reproduce session.start + session.role.override failures across shell/pre-commit contexts
- Step 2: implement deterministic override persistence model
- Step 3: validate reduced override/env ceremony

## Success Criteria
- session.start does not require repetitive manual override env pair for routine governed entry
- session role override is consistently visible where commit/pre-commit checks evaluate policy

## Definition Of Done
- linked gaps closed with evidence
- runtime role policy remains strict where required

