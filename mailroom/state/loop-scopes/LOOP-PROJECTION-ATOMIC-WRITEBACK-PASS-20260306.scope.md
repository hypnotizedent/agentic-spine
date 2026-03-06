---
loop_id: LOOP-PROJECTION-ATOMIC-WRITEBACK-PASS-20260306
created: 2026-03-06
status: active
owner: "@ronny"
scope: projection
priority: high
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: Make tracked projections self-stabilizing so capability and control-surface changes do not leave post-change tracked drift on main.
---

# Loop Scope: LOOP-PROJECTION-ATOMIC-WRITEBACK-PASS-20260306

## Objective

Make tracked projections self-stabilizing so capability and control-surface changes do not leave post-change tracked drift on main.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-PROJECTION-ATOMIC-WRITEBACK-PASS-20260306`

## Phases
- Step 1:  map tracked projection writers and drift surfaces
- Step 2:  make writeback atomic in the mutating path
- Step 3:  verify repo remains clean after projected updates

## Success Criteria
- Tracked projection writers do not leave unstaged drift after normal mutation flows
- Fast and targeted domain verify remain green

## Definition Of Done
- Loop scope updated with findings and implementation notes
- Atomic projection fix committed with validation receipts

## Findings
- Capability registration already uses an atomic four-file transaction across capability metadata and routing surfaces.
- Platform control was still split across duplicated tracked state: `platform.control.surfaces.yaml` carried a `git_transport.host_alias` copy that could drift from the canonical alias on `ssh.targets.yaml`.

## Implementation Notes
- Added a dedicated reconcile path so platform control transport aliases are projected from `ssh.targets.yaml` instead of being maintained as a second independent truth.
- Added platform control reconciliation to the shared `projection-reconcile` pass so this drift surface is handled with the rest of the tracked projections.
