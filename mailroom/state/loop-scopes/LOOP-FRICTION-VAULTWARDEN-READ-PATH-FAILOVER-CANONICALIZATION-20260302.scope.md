---
loop_id: LOOP-FRICTION-VAULTWARDEN-READ-PATH-FAILOVER-CANONICALIZATION-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: high
horizon: later
execution_readiness: runnable
objective: Add deterministic fallback pathing for vaultwarden read surfaces when canonical LAN path is unavailable.
---

# Loop Scope: LOOP-FRICTION-VAULTWARDEN-READ-PATH-FAILOVER-CANONICALIZATION-20260302

## Objective

Add deterministic fallback pathing for vaultwarden read surfaces when canonical LAN path is unavailable.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-VAULTWARDEN-READ-PATH-FAILOVER-CANONICALIZATION-20260302`

## Phases
- P1:  codify runtime target precedence for vaultwarden read capabilities
- P2:  implement fallback + explicit error-class receipts
- P3:  validate parity and close linked gap

## Success Criteria
- vaultwarden read capabilities classify LAN-down and pivot per policy
- audit/list capabilities return deterministic fallback evidence

## Definition Of Done
- target-selection contract updated
- linked gap closed with verification receipts
