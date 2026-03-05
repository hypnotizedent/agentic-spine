---
loop_id: LOOP-RONNY-PRODUCTS-BOUNDARY-CUTOVER-PREFLIGHT-20260305
created: 2026-03-05
status: active
owner: "@ronny"
scope: ronny
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Establish canonical non-mint product boundary, scaffold, and guard rails
activation_trigger: manual
---

# Loop Scope: LOOP-RONNY-PRODUCTS-BOUNDARY-CUTOVER-PREFLIGHT-20260305

## Objective

Establish canonical non-mint product boundary, scaffold, and guard rails

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-RONNY-PRODUCTS-BOUNDARY-CUTOVER-PREFLIGHT-20260305`

## Phases
- Step 1:  Promote orphaned plan to authority
- Step 2:  Install scaffold/guard pack
- Step 3:  Generate 3 deterministic app packets

## Success Criteria
- Boundary + scaffold contracts are active and verify-covered

## Definition Of Done
- No orphaned boundary plan remains
- 3 app prompts generated from one canonical scaffold
