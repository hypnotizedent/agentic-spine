---
loop_id: LOOP-FRICTION-PRECOMMIT-ROLE-CONTEXT-INHERITANCE-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: high
horizon: later
execution_readiness: runnable
objective: "Eliminate role-context and write-scope friction between runtime sessions and pre-commit hook subshells."
---

# Loop Scope: LOOP-FRICTION-PRECOMMIT-ROLE-CONTEXT-INHERITANCE-20260302

## Objective

Eliminate role-context and write-scope friction between runtime sessions and pre-commit hook subshells.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-PRECOMMIT-ROLE-CONTEXT-INHERITANCE-20260302`

## Phases
- Step 1: reproduce role-policy and write-scope failures in commit/pre-commit path
- Step 2: implement deterministic role inheritance and governance-safe write-scope model
- Step 3: validate commit path behavior and close linked friction gaps

## Success Criteria
- session role overrides are visible in pre-commit context without manual env var choreography
- governance mutation commits do not require clearing terminal identity env vars
- `session.start`, `gaps.close`, and `docs.projection.sync` have deterministic role-policy behavior

## Definition Of Done
- linked gaps fixed with evidence
- no regression in runtime role safety controls

