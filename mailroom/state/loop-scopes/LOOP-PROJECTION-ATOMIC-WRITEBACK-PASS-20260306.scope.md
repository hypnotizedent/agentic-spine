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
- Wired the VM intake mutator to back up tracked surfaces, write scaffold entries through deterministic `load()` fragments, regenerate `vm.lifecycle.derived.yaml`, re-run platform control reconcile, and roll back the full change pack on scoped parity failure.
- Scoped `vm-lifecycle-derived-check` so onboarding flows can validate the mutated VM without being blocked by unrelated historical entries elsewhere in `vm.lifecycle.yaml`.
- Pulled the remaining direct tracked mutators in this lane under the same outer transaction pattern: gate registry header sync, stack discovery source registration, capability registration, and inventory ledger mutations.
- Made the canonical terminal-worker generator entrypoints transactional so routing dispatch, launcher view, worker catalog, and worker-usage doc generation roll back cleanly instead of leaving partial generated surfaces behind.
- Reconciled live `routing.dispatch.yaml` to current capability metadata so generator checks return clean after the atomic writer changes.
