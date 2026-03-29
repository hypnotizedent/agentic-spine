# Authoritative Cross-Surface State Synthesis Projection Blocker Election

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `authoritative_cross_surface_state_synthesis_projection_blocker`

## Authoritative Blocker Discovery Artifact Path

- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUTHORITATIVE_CROSS_SURFACE_STATE_SYNTHESIS_PROJECTION_BLOCKER_DISCOVERY.md` (commit `2b2cb668`)

## Authoritative Blocker Decision Artifact Path

- `/Users/ronnyworks/code/agentic-spine/docs/governance/AUTHORITATIVE_CROSS_SURFACE_STATE_SYNTHESIS_PROJECTION_BLOCKER_DECISION.md` (commit `1b6e0346`)

## Live Blocker Posture Confirmation Summary

- `HEAD` at election start is `1b6e0346`, which is the blocker decision commit; no repo-owned implementation landed after it.
- `bash ./ops/plugins/core/authority/bin/authority-concerns-projection-build --check --verify`: PASS (`concerns=10`)
- `bash surfaces/verify/d275-single-authority-per-concern-lock.sh`: PASS
- `single.authority.contract.yaml` remains generated from `authority.concerns.yaml` (`projection_of`, `generated_from`, `superseded_by` all point to the canonical concern map)
- D275 remains active in `gate.registry.yaml`: `retired: false`, `mode: enforce`, `category: ssot-hygiene`, `gate_class: invariant`
- D275 remains assigned in `gate.execution.topology.yaml` (line 911)
- `authority.concerns.projection.build` remains registered in `ops/capabilities.yaml` as `lifecycle: ready`, `safety: mutating`
- Compatibility projection chain remains live beyond D275: `projection.reconcile.allowlist.txt` includes the file, `runtime.bootstrap.contract.yaml` references `projection.reconcile`, `freshness.reconcile.contract.yaml` refreshes via `projection.reconcile`, `recovery.actions.yaml` has recovery wrappers
- `./bin/ops cap run platform.control.surface.status`: PASS
- `./bin/ops cap run host.claude.entrypoint.status`: PASS with 2 non-blocking adapter warnings
- `./bin/ops cap run spine.control.tick -- --fast --json`: completes
- No material live-posture change invalidated the blocker decision boundary.

## Exact Elected Result

- `authorize_authoritative_cross_surface_state_synthesis_implementation`

## Explicit Rationale

The blocker discovery at `2b2cb668` proved the prior 7-surface elected slice had a write-boundary omission: `single.authority.contract.yaml` must regenerate in the same commit as any non-noop `authority.concerns.yaml` mutation. The blocker decision at `1b6e0346` froze the corrected 8-surface boundary as `concern_map_plus_compatibility_projection_alignment`. Live posture reconfirmation at election time shows no material change since the decision: D275 remains active and enforcing, the generator is healthy, the projection-consumer chain is coherent, and all platform checks pass. The corrected boundary adds exactly one surface (the mandatory generated compatibility projection) to the previously elected 7-surface slice without broadening the concern. Authorization is granted.

## Implementation Authorized

- Yes.

## Exact Authorized Implementation Boundary

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

### Implementation Constraints

- `single.authority.contract.yaml` must land in the same commit as any non-noop `authority.concerns.yaml` mutation.
- `single.authority.contract.yaml` must be regenerated via the existing `authority-concerns-projection-build` generator; do not hand-author.
- Generator code remains read-only support; no code changes.
- D275 remains active and must not be weakened, retired, or worked around.

## Preserved Read-Only Support / Evidence Surfaces

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

## Preserved Deferred Surfaces

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

## Preserved Non-Goals

- Retirement of `single.authority.contract.yaml` or D275
- Generator code mutation
- Projection-reconcile consumer-chain mutation
- Capability registration/deregistration beyond concern-map marker reconciliation
- Gate registry metadata changes
- Broad surface metabolism audit implementation
- Home-level adapter mutation
- Any implementation in this pass

## Election Answers

1. Is the corrected 8-surface slice authorized now? **Yes.**
2. What exact 8 write surfaces are authorized? `authority.concerns.yaml`, `single.authority.contract.yaml`, `AGENTS.md`, `CLAUDE.md`, `ops/capabilities.yaml`, `gate.execution.topology.yaml`, `intake.lifecycle.contract.yaml`, `platform.control.surfaces.yaml`.
3. Does this election preserve that:
   - No implementation occurs in the election pass: **Yes.**
   - `single.authority.contract.yaml` must land in the same commit as non-noop `authority.concerns.yaml` mutation: **Yes.**
   - Generator code remains read-only support: **Yes.**
   - D275 remains active and unchanged: **Yes.**
   - `gate.registry.yaml` remains read-only evidence: **Yes.**
   - Projection-consumer-chain surfaces remain read-only support: **Yes.**
   - Capability-definition rewiring remains deferred: **Yes.**
   - Home-level adapter changes remain deferred: **Yes.**
   - Prompt/runtime semantics remain deferred: **Yes.**
   - Protocol runtime handoffs remain deferred: **Yes.**
   - Autonomous multi-node work remains deferred: **Yes.**

## Timeline Confirmation

| Date | Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | Widened structural + worker-projection implementation at `11bf71a2` | D411 blocker lane closure | Already landed |
| 2026-03-29 | discovery landed | Cross-surface discovery at `3ec69e0a` | Clean synced baseline | Already landed |
| 2026-03-29 | decision landed | Cross-surface decision at `6c1c1610` | Discovery committed and pushed | Already landed |
| 2026-03-29 | election landed | Cross-surface election at `6f326b5f` | Discovery + decision committed and pushed | Already landed |
| 2026-03-29 | implementation blocked | No repo-owned landing because compatibility projection sat outside elected write set | Election authorized 7-surface slice but not its generated output | Already recorded |
| 2026-03-29 | discovery landed | Projection-blocker discovery at `2b2cb668` | Clean synced baseline plus live compatibility-chain recheck | Already landed |
| 2026-03-29 | decision landed | Projection-blocker decision at `1b6e0346` | Discovery committed and live posture matching discovery truth | Already landed |
| 2026-03-29 | election landed | This projection-blocker election authorizing the corrected 8-surface slice | Discovery + decision committed and pushed | Would have slipped if live posture had materially changed after blocker decision |
| After election | bounded implementation target | Concern-map reconciliation with same-pass compatibility projection landing on all 8 authorized write surfaces | This election authorization | Slips if implementation proves generator mutation or another deferred concern is strictly required |

## Exact Next Action

- `authoritative_cross_surface_state_synthesis_implementation`
