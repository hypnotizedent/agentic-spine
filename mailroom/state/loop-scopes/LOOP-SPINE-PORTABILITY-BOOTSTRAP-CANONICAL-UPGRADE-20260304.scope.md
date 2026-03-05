---
loop_id: LOOP-SPINE-PORTABILITY-BOOTSTRAP-CANONICAL-UPGRADE-20260304
created: 2026-03-05
status: active
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Bootstrap portability hardening to enterprise-ready init/prompt/experiment surfaces
---

# Loop Scope: LOOP-SPINE-PORTABILITY-BOOTSTRAP-CANONICAL-UPGRADE-20260304

## Objective

Bootstrap portability hardening to enterprise-ready init/prompt/experiment surfaces

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-SPINE-PORTABILITY-BOOTSTRAP-CANONICAL-UPGRADE-20260304`

## Phases
- W1-A:  runtime bootstrap contract baseline + path inventory freeze
- W1-B:  spine.init and spine.doctor capability delivery
- W1-C:  bootstrap portability verify locks
- W1-D:  prompt lineage contract + receipt propagation
- W1-E:  experiment compare capability + governance enforcement

## Success Criteria
- All W1 wave commits exist with receipts and verify evidence
- Fast and loop_gap verify pass post-wave
- Prompt lineage appears in EXEC receipts

## Definition Of Done
- Loop scope, contracts, capabilities, and gates are committed
- Post-change evidence matrix captured in final report
