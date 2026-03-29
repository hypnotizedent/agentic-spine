# Authoritative Cross-Surface State Synthesis Projection Blocker Discovery

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `authoritative_cross_surface_state_synthesis_projection_blocker`

## Blocked Implementation Summary

- The previously elected `concern_map_to_live_surface_reconciliation` implementation at `6f326b5f` did not durably land.
- No repo-owned implementation commit landed after election.
- The blocker was not a dirty baseline or a broken generator. It was that any non-noop mutation of `ops/bindings/authority.concerns.yaml` would require same-pass regeneration of `ops/bindings/single.authority.contract.yaml`, but that compatibility projection sat outside the elected 7-surface write boundary.
- The baseline compatibility chain is still live and currently healthy on `HEAD`: `bash ./ops/plugins/core/authority/bin/authority-concerns-projection-build --check --verify` passes, and standalone `D275` passes.
- The blocker seam is therefore a boundary error around a live compatibility-projection dependency, not proof that the concern map should stop being canonical.

## Exact Compatibility-Projection Residue Table

| Surface | Seam role | Live truth | Ownership class | Why it matters |
|---|---|---|---|---|
| `ops/bindings/authority.concerns.yaml` | Canonical concern-map authority | `status: authoritative`; `migration.supersedes` names `ops/bindings/single.authority.contract.yaml`; current map still resolves cleanly for `10` families and `21` sources | canonical repo authority | Any non-noop reconciliation starts here. |
| `ops/bindings/single.authority.contract.yaml` | Generated compatibility projection | `projection_of: ops/bindings/authority.concerns.yaml`; `do_not_use_for_runtime: true`; `superseded_by: ops/bindings/authority.concerns.yaml` | governed compatibility output | Same-pass regeneration is required whenever the canonical concern map changes. |
| `ops/plugins/core/authority/bin/authority-concerns-projection-build` | Generator and verifier | Still builds the compatibility projection from `authority.concerns.yaml`; `--check --verify` passes on baseline | generator support surface | Proves the blocker is boundary omission, not generator breakage. |
| `surfaces/verify/d275-single-authority-per-concern-lock.sh` | Standalone enforcement lock | Still active and passes; invokes `authority-concerns-projection-build --check --verify` | enforcement support surface | Makes projection drift a live enforced invariant, so concern-map mutation and projection refresh are inseparable in practice. |
| `ops/bindings/gate.registry.yaml` | Gate truth for D275 | `D275` is active, `retired: false`, `mode: enforce`, `check_script: surfaces/verify/d275-single-authority-per-concern-lock.sh` | read-only gate evidence | Confirms D275 is live and not stale residue. |
| `ops/bindings/gate.execution.topology.yaml` | Domain/topology truth for D275 | `D275` remains assigned to `primary_domain: core` and `family: ssot-hygiene` | read-only topology evidence for this blocker seam | Confirms the lock still belongs to live governed enforcement. |
| `ops/capabilities.yaml` | Capability registration for the generator | `authority.concerns.projection.build` remains registered as `lifecycle: ready` and `safety: mutating`; `projection.reconcile` also remains live | mixed read-only evidence; previously elected write surface in parent concern | Shows the compatibility chain is still an active governed execution path. |
| `ops/plugins/core/kernel/docs/bin/projection-reconcile` | Runtime projection consumer | Tracks `ops/bindings/single.authority.contract.yaml` and invokes `authority-concerns-projection-build` in its reconcile flow | live projection-consumer support surface | Shows the blocker is not D275-only; the compatibility output also sits inside a live reconcile pipeline. |
| `ops/bindings/projection.reconcile.allowlist.txt` | Commit-scope support for projection reconcile | Explicitly includes `ops/bindings/single.authority.contract.yaml` | live projection-consumer support surface | Confirms the compatibility output is expected in governed projection commits. |
| `ops/bindings/recovery.actions.yaml` | Recovery wrapper for projection reconcile | `recover-projection-reconcile-d85` and `recover-projection-reconcile-d285` still call `projection.reconcile` | live recovery support surface | Extends the compatibility chain into recovery automation without requiring generator mutation. |
| `ops/bindings/runtime.bootstrap.contract.yaml` | Runtime bootstrap reference | `reconcile_entrypoint: ./bin/ops cap run projection.reconcile` | live bootstrap support surface | Keeps the projection chain in the governed runtime bootstrap path. |
| `ops/bindings/freshness.reconcile.contract.yaml` | Freshness refresh mapping | `D309` still refreshes via `projection.reconcile` | live refresh support surface | Shows projection reconcile remains part of current recency/repair expectations. |

## Exact Consumer/Generator Ownership Summary

- Canonical source of truth:
  - `ops/bindings/authority.concerns.yaml`
- Compatibility output that must stay synchronized with the canonical source:
  - `ops/bindings/single.authority.contract.yaml`
- Generator that owns the compatibility output shape:
  - `ops/plugins/core/authority/bin/authority-concerns-projection-build`
- Enforcement owner for projection drift:
  - `surfaces/verify/d275-single-authority-per-concern-lock.sh`
- Gate/topology evidence that the lock is live:
  - `ops/bindings/gate.registry.yaml`
  - `ops/bindings/gate.execution.topology.yaml`
- Capability/runtime chain that still depends on the compatibility projection remaining valid:
  - `ops/capabilities.yaml`
  - `ops/plugins/core/kernel/docs/bin/projection-reconcile`
  - `ops/bindings/projection.reconcile.allowlist.txt`
  - `ops/bindings/recovery.actions.yaml`
  - `ops/bindings/runtime.bootstrap.contract.yaml`
  - `ops/bindings/freshness.reconcile.contract.yaml`

## Candidate Tranche Breakdown

### `concern_map_plus_compatibility_projection_alignment`

- Included surfaces:
  - `ops/bindings/authority.concerns.yaml`
  - `ops/bindings/single.authority.contract.yaml`
  - previously elected directly coupled repo-owned reconciliation surfaces:
    - `AGENTS.md`
    - `CLAUDE.md`
    - `ops/capabilities.yaml`
    - `ops/bindings/gate.execution.topology.yaml`
    - `ops/bindings/intake.lifecycle.contract.yaml`
    - `ops/bindings/platform.control.surfaces.yaml`
- Why bounded or not:
  - Truthfully bounded. It corrects the write-set omission that blocked the prior pass without requiring generator rewrites, D275 weakening, capability rewiring, or home-adapter mutation.
- Tranche type:
  - same-concern boundary widening
- Why it should or should not go first:
  - Should go first. The previously elected concern-map reconciliation remains the right parent concern, but it must widen to include the generated compatibility output that D275 and projection-reconcile already require.

### `compatibility_projection_consumer_chain_realignment`

- Included surfaces:
  - `ops/plugins/core/authority/bin/authority-concerns-projection-build`
  - `ops/plugins/core/kernel/docs/bin/projection-reconcile`
  - `ops/bindings/projection.reconcile.allowlist.txt`
  - `ops/bindings/recovery.actions.yaml`
  - `ops/bindings/runtime.bootstrap.contract.yaml`
  - `ops/bindings/freshness.reconcile.contract.yaml`
  - supporting capability/routing metadata
- Why bounded or not:
  - Not truthfully bounded as the next slice. The chain is currently coherent and does not itself explain the failure to land; the failure came from excluding the generated output from the prior write set.
- Tranche type:
  - mixed and therefore risky
- Why it should or should not go first:
  - Should not go first. It would broaden into runtime/recovery architecture even though the generator and live consumer chain are already functioning.

### `narrow_away_from_concern_map_mutation`

- Included surfaces:
  - only non-map comparison surfaces from the previously elected slice, such as `AGENTS.md`, `CLAUDE.md`, `ops/bindings/platform.control.surfaces.yaml`, `ops/capabilities.yaml`, `ops/bindings/gate.execution.topology.yaml`, and `ops/bindings/intake.lifecycle.contract.yaml`
- Why bounded or not:
  - Not truthfully bounded. The prior discovery and decision already established that these surfaces were blocked by an incomplete concern-map relationship, not by independent marker-only residue.
- Tranche type:
  - mixed and therefore risky
- Why it should or should not go first:
  - Should not go first. It would work around the canonical map instead of reconciling it.

### `separate_projection_chain_concern`

- Included surfaces:
  - `ops/bindings/authority.concerns.yaml`
  - `ops/bindings/single.authority.contract.yaml`
  - `ops/plugins/core/authority/bin/authority-concerns-projection-build`
  - `surfaces/verify/d275-single-authority-per-concern-lock.sh`
- Why bounded or not:
  - Artificially bounded. It would split the compatibility output away from the exact concern-map reconciliation that caused the attempted implementation in the first place.
- Tranche type:
  - separate blocker concern
- Why it should or should not go first:
  - Should not go first. The blocker is part of the same high-level cross-surface synthesis concern, not a new standalone meaning lane.

### `defer_or_out_of_scope`

- Included surfaces:
  - capability-definition rewiring
  - home-level adapter changes
  - prompt/runtime semantics
  - protocol runtime handoffs
  - autonomous multi-node work
- Why bounded or not:
  - Bounded as exclusions only.
- Tranche type:
  - defer_or_out_of_scope
- Why it should or should not go first:
  - Should not go first. None of these caused the blocked landing.

## Exact Recommended Next Tranche

- `concern_map_plus_compatibility_projection_alignment`
- `single.authority.contract.yaml` must enter the same write boundary as `authority.concerns.yaml` for any non-noop concern-map reconciliation.
- `D275` makes the compatibility projection builder and generated output inseparable from concern-map mutation in practice, because it enforces `--check --verify` against the projection on every relevant pass.
- `gate.registry.yaml` remains read-only evidence next; its D275 metadata is already truthful.
- `gate.execution.topology.yaml` and `ops/capabilities.yaml` do not become read-only blocker evidence only; they remain part of the parent concern’s unresolved repo-owned reconciliation seam unless the renewed decision explicitly narrows them away.
- This remains the same high-level `authoritative_cross_surface_state_synthesis` concern with a corrected boundary, not a separate blocker concern.
- Capability-definition rewiring remains separate.
- Home-level adapter changes remain separate.
- Prompt/runtime semantics remain separate.
- Protocol runtime handoffs remain separate.
- Autonomous multi-node work remains a downstream separate `new_truth`.

## Explicit Handling Of `single.authority.contract.yaml`

- Treat it as a mandatory generated compatibility output, not as an independent authority surface.
- Do not retire it in the next slice.
- Do not hand-author it divergently from the generator.
- Any next implementation that mutates `authority.concerns.yaml` must land the regenerated compatibility projection in the same governed commit.

## Explicit Handling Of D275

- `D275` remains truthful live enforcement and should not be weakened, retired, or worked around.
- The gate currently proves two things at once:
  - exactly one authoritative source per concern remains enforced
  - the generated compatibility projection remains in sync with the canonical map
- The next slice must preserve that enforcement shape while correcting the write boundary.

## Explicit Handling Of The Generator Boundary

- `ops/plugins/core/authority/bin/authority-concerns-projection-build` remains read-only support for the next slice.
- Current discovery found no evidence that generator code changes are required.
- The next implementation should use the existing generator and land its output, not broaden into generator mutation unless a later pass proves the generator itself is wrong.

## Explicit Handling Of Deferred Concerns

- Capability-definition rewiring remains separate from this blocker seam.
- Home-level adapter work remains separate under `root.authority.contract.yaml`.
- Prompt/runtime semantics remain separate.
- Protocol runtime handoffs remain separate.
- Autonomous multi-node work remains downstream `new_truth`.

## Dated Timeline

| Date | Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | Widened structural + worker-projection implementation at `11bf71a2` | D411 blocker discovery, decision, election, and implementation closure | Already landed |
| 2026-03-29 | discovery landed | Cross-surface discovery at `3ec69e0a` | Clean synced baseline plus live repo and read-only status recheck | Already landed |
| 2026-03-29 | decision landed | Cross-surface decision at `6c1c1610` | Discovery artifact committed and pushed | Already landed |
| 2026-03-29 | election landed | Cross-surface election at `6f326b5f` | Discovery + decision artifacts committed and pushed | Already landed |
| 2026-03-29 | implementation blocked | No repo-owned landing because the compatibility projection sat outside the elected write set | Election authorized the 7-surface slice but not its generated compatibility output | Slipped as soon as non-noop concern-map mutation required `single.authority.contract.yaml` regeneration |
| 2026-03-29 | discovery | This projection-blocker discovery artifact with corrected seam classification | Clean synced baseline plus live compatibility-chain recheck | Would have slipped if the generator or D275 had already been retired or if repo-owned implementation had landed after `6f326b5f` |
| 2026-03-29 or next clean landing window | decision target | Corrected boundary decision for the cross-surface synthesis concern | This discovery artifact committed and pushed | Slips if decision cannot freeze whether the prior non-projection surfaces remain in the same widened slice |
| 2026-03-29 or next clean landing window after decision | election target | Authorization result for the corrected widened slice | Discovery + decision artifacts committed and pushed | Slips if operator review concludes the widened slice still hides deferred work |
| After election | bounded implementation target if authorized | Concern-map reconciliation with same-pass compatibility projection landing | Election authorization | Slips if implementation proves generator mutation or another deferred concern is strictly required |

## Open Questions For Decision Stage

- Does the corrected write boundary remain the previously elected 7 repo-owned surfaces plus `ops/bindings/single.authority.contract.yaml`, or can any of the prior non-projection surfaces be truthfully narrowed away?
- Do `ops/capabilities.yaml` and `ops/bindings/gate.execution.topology.yaml` still require same-pass concern-map normalization once the compatibility projection is brought in-scope, or should the renewed boundary reduce to a smaller concern-map-first slice?
- Is `ops/bindings/platform.control.surfaces.yaml` still best handled in the same widened slice, or should it remain read-only evidence until the concern-map plus compatibility layer lands?
- After the compatibility output is restored to the write boundary, is there any remaining live reason to keep the projection-reconcile consumer chain unchanged, or does later retirement/decomposition work need its own separate concern?

## Exact Proposed Next Action

- `authoritative_cross_surface_state_synthesis_decision`
