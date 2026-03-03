---
loop_id: LOOP-ORCHESTRATOR-FAILCLOSED-DISPATCH-ENFORCEMENT-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: core
priority: high
horizon: now
execution_mode: orchestrator_subagents
objective: Enforce fail-closed orchestration topology so orchestrator_subagents loops cannot mutate without deterministic lane/worktree locks and kickoff contract artifacts.
---

# Loop Scope: LOOP-ORCHESTRATOR-FAILCLOSED-DISPATCH-ENFORCEMENT-20260303

## Objective

Make orchestrator-subagent execution fail-closed by default across verify gates, mutation-time capability dispatch, and operator kickoff flow.

## Required Controls

1. D330 fail-closed for active/open/draft loop topology metadata
2. D331 fail-closed for incomplete orchestrator packets
3. Fast verify enforcement wiring for D330+D331
4. Mutation-time lock/claim guard in `cap.sh` for orchestrator_subagents loops
5. Single kickoff capability for packet + deterministic lane worktrees/branches + lock claims + worker prompt emission

## Success Criteria

- `verify.run -- fast` fails when D330 topology fields are missing
- `verify.run -- fast` fails when D331 packet fields are incomplete
- Mutating capabilities are blocked for orchestrator-subagent loops without lock evidence
- `orchestration.wave.kickoff` creates deterministic lanes, packet artifact, lock claims, and canonical prompts
- Governance docs and operational gap tracking updated with evidence
