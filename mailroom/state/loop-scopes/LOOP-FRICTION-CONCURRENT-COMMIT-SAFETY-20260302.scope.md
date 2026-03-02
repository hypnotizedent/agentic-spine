---
loop_id: LOOP-FRICTION-CONCURRENT-COMMIT-SAFETY-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: medium
horizon: later
execution_readiness: runnable
objective: "Eliminate multi-agent commit collision behavior where unstaged unrelated changes are swept into governance commits and gap closures are lost."
---

# Loop Scope: LOOP-FRICTION-CONCURRENT-COMMIT-SAFETY-20260302

## Objective

Eliminate multi-agent commit collision behavior where unstaged unrelated changes are swept into governance commits and gap closures are lost.

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Gap Status**: `./bin/ops cap run gaps.status -- --json`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-CONCURRENT-COMMIT-SAFETY-20260302`

## Phases
- Step 1: Reproduce concurrent commit collision behavior deterministically.
- Step 2: Add safe-commit guardrails for staged-only governance mutations.
- Step 3: Validate no lost gap-close commits under concurrent agent churn.

## Success Criteria
- `gaps.close` and related governance commits no longer capture unrelated unstaged changes.
- Commit outcomes are deterministic across concurrent terminal activity.

## Definition Of Done
- Linked systemic gap(s) closed with evidence.
- No regression in existing hook policy and mutation auditability.
