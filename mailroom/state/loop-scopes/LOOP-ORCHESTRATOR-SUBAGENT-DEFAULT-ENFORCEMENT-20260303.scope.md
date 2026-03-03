---
loop_id: LOOP-ORCHESTRATOR-SUBAGENT-DEFAULT-ENFORCEMENT-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: orchestrator
priority: high
horizon: later
execution_readiness: blocked
objective: Enforce orchestrator_subagents workflow as default execution topology through contracts and gates
---

# Loop Scope: LOOP-ORCHESTRATOR-SUBAGENT-DEFAULT-ENFORCEMENT-20260303

## Objective

Enforce orchestrator_subagents workflow as default execution topology through contracts and gates

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-ORCHESTRATOR-SUBAGENT-DEFAULT-ENFORCEMENT-20260303`

## Phases
- Step 1: capture and classify findings
- Step 2: implement changes
- Step 3: verify and close out

## Success Criteria
- All linked gaps/proposals are captured and linked to this loop.
- Relevant verify pack(s) pass.

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
