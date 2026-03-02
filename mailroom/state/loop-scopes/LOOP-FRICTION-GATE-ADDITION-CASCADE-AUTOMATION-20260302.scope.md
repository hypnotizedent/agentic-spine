---
loop_id: LOOP-FRICTION-GATE-ADDITION-CASCADE-AUTOMATION-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: medium
horizon: later
execution_readiness: runnable
objective: "Automate gate-addition cascade updates and trailer discoverability to remove sequential pre-commit failure loops."
---

# Loop Scope: LOOP-FRICTION-GATE-ADDITION-CASCADE-AUTOMATION-20260302

## Objective

Automate gate-addition cascade updates and trailer discoverability to remove sequential pre-commit failure loops.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-GATE-ADDITION-CASCADE-AUTOMATION-20260302`

## Phases
- Step 1: capture required mutation surfaces for gate registration
- Step 2: implement/extend atomic gate registration workflow
- Step 3: verify D127/D85/D128 path is deterministic and first-pass successful

## Success Criteria
- new gate onboarding updates registry, topology, and projections in one governed flow
- D128 trailer requirements are discoverable before commit failure

## Definition Of Done
- linked gaps fixed with evidence
- no regression in gate registry integrity

