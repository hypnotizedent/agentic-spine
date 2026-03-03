---
loop_id: LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: governance
execution_mode: orchestrator_subagents
priority: high
horizon: now
execution_readiness: runnable
objective: Execute post-merge continuation waves for universal intake chain enforcement, Home Assistant end-to-end closure, and shared-authority phase-2 hardening without cross-lane collisions.
---

# Loop Scope: LOOP-POST-MERGE-UNIVERSAL-CHAIN-HA-SHARED-AUTH-20260303

## Objective

Coordinate three merged workstreams into one deterministic continuation:
1. Universal 3-stage chain promotion (intake -> master -> projection/fork)
2. Home Assistant end-to-end cleanup execution against reliability contract
3. Shared-authority phase-2 hardening from lock-based safety toward storage-tier strategy

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Packet health**: `surfaces/verify/d331-orchestrator-closeout-lock.sh`
- **Topology**: `surfaces/verify/d330-execution-topology-enforcement.sh`

## Step Chain Contract

- Step 1 (`intake`): governed intake envelope captured once per artifact family.
- Step 2 (`master`): canonical master registry contains normalized records and ownership.
- Step 3 (`projection`): domain-specific filtered views are generated from master with lineage proof.

This chain is universal across domains (home-assistant, network, hardware, mint, finance, surveillance, future domains).

## Phases

- Step 1: Universal chain execution hardening and domain adoption matrix.
- Step 2: HA runtime closure wave (offsite-safe tasks + on-site queue packet).
- Step 3: Shared-authority phase-2 plan (operational.gaps/path.claims/traffic backend strategy and migration packet).
- Step 4: Integration verify, merge closeout receipts, and next-wave handoff.

## Success Criteria

- One canonical chain contract is referenced by all active domain intake workflows.
- HA governance/doc surfaces stay lean and indexed, with runtime gaps explicitly classified by on-site vs runnable-now.
- Shared-authority phase-2 packet is ready with explicit mutation-surface boundaries and no collisions.
- Fast verify remains green on integrated main.

## Definition Of Done

- Orchestrator packet complete with reconciliation fields.
- All lane deliverables merged or handed off with explicit blockers.
- `verify.run -- fast` PASS on closeout.
