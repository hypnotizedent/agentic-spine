# Authoritative Cross-Surface State Synthesis Projection Blocker Decision

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `authoritative_cross_surface_state_synthesis_projection_blocker`

## Authoritative Blocker Discovery Artifact Path

- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUTHORITATIVE_CROSS_SURFACE_STATE_SYNTHESIS_PROJECTION_BLOCKER_DISCOVERY.md` (commit `2b2cb668`)

## Live Blocker Recheck Summary

- `HEAD` at decision start is `2b2cb668`, which is the blocker discovery commit; no repo-owned implementation landed after it.
- `bash ./ops/plugins/core/authority/bin/authority-concerns-projection-build --check --verify`: PASS (`concerns=10`)
- `bash surfaces/verify/d275-single-authority-per-concern-lock.sh`: PASS
- `single.authority.contract.yaml` remains generated from `authority.concerns.yaml` (`projection_of`, `generated_from`, `superseded_by` all point to the canonical concern map)
- D275 remains active in `gate.registry.yaml`: `retired: false`, `mode: enforce`, `category: ssot-hygiene`, `gate_class: invariant`
- D275 remains assigned in `gate.execution.topology.yaml` (line 911)
- `authority.concerns.projection.build` remains registered in `ops/capabilities.yaml` as `lifecycle: ready`, `safety: mutating`
- Compatibility projection chain remains live beyond D275: `projection.reconcile.allowlist.txt` includes the file, `runtime.bootstrap.contract.yaml` references `projection.reconcile`, `freshness.reconcile.contract.yaml` refreshes via `projection.reconcile`, `recovery.actions.yaml` has recovery wrappers
- `./bin/ops cap run platform.control.surface.status`: PASS
- `./bin/ops cap run host.claude.entrypoint.status`: PASS with 2 non-blocking adapter warnings
- `./bin/ops cap run spine.control.tick -- --fast --json`: PASS
- No material live-posture change invalidated the blocker discovery boundary.

## Exact Tranche Decision

- `concern_map_plus_compatibility_projection_alignment`

## Justification

The blocker discovery proved that the prior 7-surface slice was the correct parent scope but had a write-boundary omission: `ops/bindings/single.authority.contract.yaml` must regenerate in the same commit as any non-noop `authority.concerns.yaml` mutation. D275 enforces `--check --verify` against the compatibility projection on every relevant pass. The projection-reconcile runtime chain also depends on that file remaining valid. Adding the generated compatibility output to the write set corrects the boundary error without broadening the concern.

A narrower compatibility-only slice would not work because the original concern — concern-map reconciliation against live repo truth — is the reason the compatibility projection needs to change at all. A broader consumer-chain slice would not work because the generator, D275, and the projection-reconcile chain are all currently healthy and do not themselves require mutation.

## Exact Corrected Implementation Boundary

### In-Scope Write Surfaces (8)

| Surface | Role in this slice |
|---|---|
| `ops/bindings/authority.concerns.yaml` | Canonical concern-map authority — reconcile against live repo truth |
| `ops/bindings/single.authority.contract.yaml` | Generated compatibility projection — regenerate from reconciled concern map via existing generator |
| `AGENTS.md` | Repo-root entry anchor — marker normalization for concern-map relationship |
| `CLAUDE.md` | Subordinate thin pointer — subordinate marker normalization under same repo entry-surface family |
| `ops/capabilities.yaml` | Concern-map reconciliation — add or correct concern-map markers/sources |
| `ops/bindings/gate.execution.topology.yaml` | Concern-map reconciliation — add or correct concern-map markers/sources |
| `ops/bindings/intake.lifecycle.contract.yaml` | Concern-map reconciliation — add or correct concern-map markers/sources |
| `ops/bindings/platform.control.surfaces.yaml` | Standalone concern family registration in the concern map |

### Read-Only Support / Evidence Surfaces

| Surface | Why read-only |
|---|---|
| `ops/bindings/root.authority.contract.yaml` | Truthful; stays outside concern map |
| `ops/plugins/core/authority/bin/authority-concerns-projection-build` | Generator is healthy; no code changes needed |
| `surfaces/verify/d275-single-authority-per-concern-lock.sh` | Enforcement is healthy; no weakening or changes |
| `ops/bindings/gate.registry.yaml` | D275 metadata already truthful |
| `ops/plugins/core/kernel/docs/bin/projection-reconcile` | Consumer chain functioning; no mutation required |
| `ops/bindings/projection.reconcile.allowlist.txt` | Already includes `single.authority.contract.yaml` |
| `ops/bindings/recovery.actions.yaml` | Recovery wrappers functioning; no mutation required |
| `ops/bindings/runtime.bootstrap.contract.yaml` | Bootstrap reference functioning; no mutation required |
| `ops/bindings/freshness.reconcile.contract.yaml` | Freshness mapping functioning; no mutation required |

### Deferred Surfaces

| Surface class | Why deferred |
|---|---|
| Home-level adapter targets under `~/.claude/` and `~/.codex/` | Separate concern under root-authority policy |
| Capability-definition command/path rewiring beyond concern-map marker reconciliation | Separate concern; only markers and sources change in this slice |
| Prompt/runtime semantics surfaces | Separate concern |
| Protocol runtime handoff surfaces | Separate concern |
| Autonomous multi-node implementation | Downstream separate `new_truth` |
| Projection/generator decomposition beyond current file-set reconciliation | Separate concern; generator is healthy |
| Git workflow discipline codification | Separate doctrine concern |
| H3 publication implementation | Inactive pending separate operator activation |
| Extraction | Inactive; Horizon 4 |

### Non-Goals

- Retirement of `single.authority.contract.yaml` or D275
- Generator code mutation
- Projection-reconcile consumer-chain mutation
- Capability registration/deregistration beyond concern-map marker reconciliation
- Gate registry metadata changes
- Broad surface metabolism audit implementation
- Home-level adapter mutation
- Any implementation in this pass

## Explicit Surface Decisions

### `ops/bindings/authority.concerns.yaml`

- Remains the canonical concern-map authority.
- Any non-noop reconciliation of concern families, sources, or markers starts here.
- Must land in the same commit as the regenerated compatibility projection.

### `ops/bindings/single.authority.contract.yaml`

- Remains a generated compatibility projection.
- Must be regenerated via the existing `authority-concerns-projection-build` generator whenever `authority.concerns.yaml` changes.
- Must land in the same commit as the concern-map mutation.
- Do not hand-author. Do not retire in this slice.

### `AGENTS.md`

- Stays the authoritative repo-root entry anchor.
- Concern-map relationship marker normalization only; no content rewrite.

### `CLAUDE.md`

- Stays the subordinate thin-pointer surface under the same repo entry-surface family as `AGENTS.md`.
- Subordinate marker normalization only; no content rewrite.

### `ops/capabilities.yaml`

- Concern-map marker and source reconciliation only.
- No command/path rewiring, no capability registration/deregistration.

### `ops/bindings/gate.execution.topology.yaml`

- Concern-map marker and source reconciliation only.
- No topology restructuring, no gate reassignment.

### `ops/bindings/intake.lifecycle.contract.yaml`

- Concern-map marker and source reconciliation only.
- No intake flow changes.

### `ops/bindings/platform.control.surfaces.yaml`

- Becomes its own standalone concern family in the concern map.
- No content changes beyond concern-map registration.

### `ops/bindings/gate.registry.yaml`

- Remains read-only evidence. D275 metadata is already truthful.

### Generator Write Scope

- Generator code (`authority-concerns-projection-build`) remains read-only support.
- No code changes needed; the generator is healthy and produces correct output.
- Implementation uses the generator as-is to regenerate the compatibility projection.

### Projection-Consumer-Chain Write Scope

- All consumer-chain surfaces (`projection-reconcile`, `projection.reconcile.allowlist.txt`, `recovery.actions.yaml`, `runtime.bootstrap.contract.yaml`, `freshness.reconcile.contract.yaml`) remain read-only support.
- The chain is currently coherent and requires no mutation for this slice.

### Capability-Definition Rewiring

- Remains deferred. Only concern-map markers and sources change in `ops/capabilities.yaml`; no command paths, script paths, or capability definitions are modified.

## Dated Timeline

| Date | Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | Widened structural + worker-projection implementation at `11bf71a2` | D411 blocker lane closure | Already landed |
| 2026-03-29 | discovery landed | Cross-surface discovery at `3ec69e0a` | Clean synced baseline | Already landed |
| 2026-03-29 | decision landed | Cross-surface decision at `6c1c1610` | Discovery committed and pushed | Already landed |
| 2026-03-29 | election landed | Cross-surface election at `6f326b5f` | Discovery + decision committed and pushed | Already landed |
| 2026-03-29 | implementation blocked | No repo-owned landing because compatibility projection sat outside elected write set | Election authorized 7-surface slice but not its generated output | Slipped on concern-map mutation requiring same-pass projection regeneration |
| 2026-03-29 | discovery landed | Projection-blocker discovery at `2b2cb668` | Clean synced baseline plus live compatibility-chain recheck | Already landed |
| 2026-03-29 | decision landed | This projection-blocker decision freezing the corrected 8-surface boundary | Discovery committed and live posture matching discovery truth | Would have slipped if live posture had changed after blocker discovery |
| 2026-03-29 or next clean landing window | election target | Authorization result for the corrected 8-surface slice | Discovery + decision committed and pushed | Slips if operator review concludes the widened slice still hides deferred work |
| After election | bounded implementation target if authorized | Concern-map reconciliation with same-pass compatibility projection landing on all 8 authorized write surfaces | Election authorization | Slips if implementation proves generator mutation or another deferred concern is strictly required |

## Open Questions For Election Stage

- Does the operator ratify the 8-surface write boundary as frozen?
- Is the operator satisfied that capability-definition rewiring stays deferred?
- Is the operator satisfied that home-level adapter changes stay deferred?
- After the 8-surface implementation lands, should the next concern be the remaining cross-surface drift (stale concern families), or a different priority?

## Exact Proposed Next Action

- `authoritative_cross_surface_state_synthesis_election`
