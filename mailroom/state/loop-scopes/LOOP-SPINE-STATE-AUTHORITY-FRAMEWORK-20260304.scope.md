---
loop_id: LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304
created: 2026-03-04
status: closed
owner: "@ronny"
scope: spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Establish canonical state authority framework so runtime state migrations are contract-first, generated, and drift-gated.
---

# Loop Scope: LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304

## Objective

Establish canonical state authority framework so runtime state migrations are contract-first, generated, and drift-gated.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-SPINE-STATE-AUTHORITY-FRAMEWORK-20260304`

## Phases
- Tier 1:  contract and inventory freeze
- Tier 2:  generator and registration projection
- Tier 3:  admission and write-firewall enforcement
- Tier 4:  reconcile supervisor orchestration
- Tier 5:  certification and tombstoning

## Success Criteria
- All mutable subsystems declare canonical state-module contracts
- Mutating state capabilities are generator-backed and admission-gated
- Scheduled reconcile + parity SLO enforced for state authorities

## Definition Of Done
- Loop packet, gaps, and planning artifacts committed
- Framework capabilities + gate pack implemented
- Fast + loop_gap verify receipts captured
