---
loop_id: LOOP-FRICTION-VOCABULARY-AND-ARG-PARSING-EDGE-CASES-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: low
horizon: later
execution_readiness: runnable
objective: "Normalize user-facing vocabulary constraints and arg parsing edge-case behavior to avoid avoidable command failures."
---

# Loop Scope: LOOP-FRICTION-VOCABULARY-AND-ARG-PARSING-EDGE-CASES-20260302

## Objective

Normalize user-facing vocabulary constraints and arg parsing edge-case behavior to avoid avoidable command failures.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-VOCABULARY-AND-ARG-PARSING-EDGE-CASES-20260302`

## Phases
- Step 1: reproduce D145 vocabulary rejection and multiline arg parsing failures
- Step 2: implement ergonomic guardrails and clear remediation hints
- Step 3: validate scope authoring and CLI invocations across shell patterns

## Success Criteria
- D145 messaging aligns with common user wording and offers alternatives
- multiline invocation of friction.ingest is robust to whitespace continuation artifacts

## Definition Of Done
- linked gaps closed with evidence
- no regression in policy enforcement correctness

