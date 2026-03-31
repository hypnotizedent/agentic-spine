# Authoritative Cross-Surface State Synthesis Discovery

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `authoritative_cross_surface_state_synthesis`

## Post-11bf71a2 Posture Summary

- `11bf71a2` landed the widened structural + worker-projection slice and closed the D411 blocker seam.
- The current `ops/bindings/authority.concerns.yaml` is internally healthy: all 10 declared concern families resolve to existing sources with their required markers present.
- The newly exposed residue is not that the current concern families are broken; it is that several live repo-owned authority surfaces are no longer represented by the concern map at all, or no longer fit the archived authoritative/projection assumptions that previously described them.
- `ops/bindings/root.authority.contract.yaml` remains truthful and still declares home-level adapter targets as non-canonical machine truth.
- `ops/bindings/platform.control.surfaces.yaml` and the read-only `platform.control.surface.status` capability agree live on n8n, Gitea, and Authentik control surfaces.
- `AGENTS.md` is a real governed repo file path, not path ambiguity.
- `CLAUDE.md` is currently a thin repo pointer by content, but it has no explicit authority marker and no declared concern-family relationship in `authority.concerns.yaml`.
- The active seam is therefore a repo-owned concern-map reconciliation problem with some marker normalization inside it, not a pure root-placement problem and not a pure home-adapter problem.

## Residue Table

| Surface | Declared concern family | Declared source path | Actual live path truth | Required marker | Marker present | State classification | Root placement | Why it matters |
|---|---|---|---|---|---|---|---|---|
| `ops/bindings/authority.concerns.yaml` | self authority for concern mapping | `ops/bindings/authority.concerns.yaml` | Canonical repo concern map; 10 families all resolve cleanly | `status: authoritative` | yes | truthful | truthful | Next slice must change the map, not work around it. |
| `ops/bindings/root.authority.contract.yaml` | not mapped in current concern map | none in `authority.concerns.yaml` | Canonical root-taxonomy contract under repo control | `status: authoritative` | yes | truthful surface, concern-map gap | truthful | Defines the repo-vs-home boundary that prevents adapter paths from becoming canonical truth. |
| `AGENTS.md` | not mapped currently; archived under `gate_metadata_surfaces` as projection | archived path `agentic-spine/AGENTS.md` | Real repo-root entry stub with governed front matter | `status: authoritative` | yes | drifted concern relationship | truthful | Proves earlier `AGENTS.md` references are real governed file paths, not ambiguity. |
| `CLAUDE.md` | not mapped currently; archived under `gate_metadata_surfaces` as projection | archived path `agentic-spine/CLAUDE.md` | Real repo-root thin pointer to repo authorities | explicit authority marker for repo entry-stub state | no | drifted and underspecified | truthful | Thin-pointer content exists, but the file is neither concern-mapped nor marker-explicit. |
| `ops/capabilities.yaml` | not mapped currently; archived as authoritative source for `capability_map_surfaces` and `intake_lifecycle_surfaces` | archived path `agentic-spine/ops/capabilities.yaml` | Live capability registry consumed across repo and generated docs | `authority_state: authoritative` if retained as source authority | no | drifted and underspecified | truthful | Cannot be normalized safely until its concern-family role is re-declared from live truth. |
| `ops/bindings/gate.execution.topology.yaml` | not mapped currently; archived as projection in `gate_topology_surfaces` | archived path `agentic-spine/ops/bindings/gate.execution.topology.yaml` | Mixed surface: hand-maintained authority sections plus generated projection sections in one file | explicit projection/authority marker consistent with its live split role | no | drifted and underspecified | truthful | Archived projection-only classification is no longer truthful for the live file shape. |
| `ops/bindings/intake.lifecycle.contract.yaml` | not mapped currently; archived as projection in `intake_lifecycle_surfaces` | archived path `agentic-spine/ops/bindings/intake.lifecycle.contract.yaml` | Live repo contract currently marks itself authoritative | archived requirement was `authority_state: projection` | no, and current file instead says `status: authoritative` | broader synthesis mismatch | truthful | This is a meaning mismatch about source-of-truth shape, not just a missing marker. |
| `ops/bindings/platform.control.surfaces.yaml` | not mapped in current or archived concern map | none in `authority.concerns.yaml` | Live authoritative platform-control contract | `status: authoritative` | yes | truthful surface, concern-map gap | truthful | Read-only status capability consumes it directly and agrees, proving unmapped live authority. |
| `~/.claude/CLAUDE.md` via `host.claude.entrypoint.status` | adapter-entry evidence only; not eligible as canonical repo authority under root policy | root-authority policy forbids home canonical truth | Home-level adapter target with 2 read-only warnings (`AGENTS.md`, `SESSION_PROTOCOL.md`) | adapter lock expectations, not repo authority marker | warnings present in status surface | adapter-entry drift | truthful home placement but non-canonical | Context only; useful evidence, but not the source of repo-governed truth. |

## Candidate Tranche Breakdown

### `authority_marker_and_source_path_normalization`

- Included surfaces:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `ops/capabilities.yaml`
  - `ops/bindings/gate.execution.topology.yaml`
  - `ops/bindings/intake.lifecycle.contract.yaml`
  - `ops/bindings/platform.control.surfaces.yaml`
  - `ops/bindings/root.authority.contract.yaml`
- Why bounded or not:
  - Superficially bounded, but not truthfully bounded because marker edits alone would hard-code unresolved source-of-truth assumptions.
- Tranche type:
  - marker normalization
- Why it should or should not go first:
  - Should not go first. The live seam is not merely missing markers; it is that the concern map no longer tells the truth about which of these surfaces are authoritative, projected, or intentionally outside the map.

### `concern_map_to_live_surface_reconciliation`

- Included surfaces:
  - `ops/bindings/authority.concerns.yaml`
  - `ops/bindings/root.authority.contract.yaml`
  - `AGENTS.md`
  - `CLAUDE.md`
  - `ops/capabilities.yaml`
  - `ops/bindings/gate.execution.topology.yaml`
  - `ops/bindings/intake.lifecycle.contract.yaml`
  - `ops/bindings/platform.control.surfaces.yaml`
- Why bounded or not:
  - Truthfully bounded to repo-owned authority declarations and repo entry stubs. It does not require generator rewrites, capability-definition rewiring, or home-adapter mutation.
- Tranche type:
  - concern-map reconciliation
- Why it should or should not go first:
  - Should go first. It freezes the live authoritative family map and only then allows later marker normalization or projection work to happen without inventing a false source hierarchy.

### `entry_stub_and_root_authority_alignment`

- Included surfaces:
  - `ops/bindings/root.authority.contract.yaml`
  - `AGENTS.md`
  - `CLAUDE.md`
  - home-level Claude entrypoint status evidence
- Why bounded or not:
  - Bounded, but too narrow for the active seam.
- Tranche type:
  - root/entry alignment
- Why it should or should not go first:
  - Should not go first. Root policy is already truthful, and entry-stub cleanup would not resolve the unmapped capability/topology/intake/platform-control surfaces.

### `repo_authority_projection_synthesis`

- Included surfaces:
  - `ops/bindings/authority.concerns.yaml`
  - `ops/capabilities.yaml`
  - `ops/bindings/gate.execution.topology.yaml`
  - `ops/bindings/intake.lifecycle.contract.yaml`
  - any future generator or projection surfaces needed to synthesize them
- Why bounded or not:
  - Not bounded enough at discovery time because it assumes a new synthesis mechanism or projection chain before the canonical family map is re-declared.
- Tranche type:
  - mixed and therefore risky
- Why it should or should not go first:
  - Should not go first. It would broaden directly into implementation design while the underlying concern-family truth is still unresolved.

### `defer_or_out_of_scope`

- Included surfaces:
  - home-level adapter canonicalization
  - capability-definition rewiring
  - prompt/runtime semantics
  - communication-protocol runtime handoffs
  - autonomous multi-node work
- Why bounded or not:
  - Bounded as explicit exclusions, not as the next slice.
- Tranche type:
  - defer_or_out_of_scope
- Why it should or should not go first:
  - Should not go first. None of these are required to classify the repo-owned authority drift exposed by `11bf71a2`.

## Exact Recommended Next Tranche

- `concern_map_to_live_surface_reconciliation`
- This is primarily a broader concern-map synthesis seam, not just a marker/source-path normalization seam.
- Home-level adapter entry stubs are contextual evidence only under `root.authority.contract.yaml`; they are not part of the next repo-governed mutation slice.
- `ops/capabilities.yaml`, `ops/bindings/gate.execution.topology.yaml`, `ops/bindings/intake.lifecycle.contract.yaml`, and repo-root `CLAUDE.md` belong in one bounded next slice because their live authority states can only be normalized truthfully after the concern map re-declares their relationship.
- Current truth does not yet require a new shared synthesis mechanism. The immediate need is bounded contract/marker/source-of-truth normalization in the concern map and its directly affected repo-owned surfaces.
- Capability-definition rewiring remains separate.
- Prompt/runtime semantics remain separate.
- Protocol runtime handoffs remain separate.
- Autonomous multi-node work remains a separate downstream `new_truth`.

## Handling of Stale Concern Families

- `backup_inventory_surfaces`
- `content_family_placement_surfaces`
- `content_family_decommission_readiness_surfaces`

These remain classified as stale concern families surfaced by `11bf71a2`. This discovery does not recommend restoring them. They should stay retired unless a later pass proves that a live authoritative surface still requires one of those families to exist.

## Handling of Drifted Source Paths

- `gate_topology_surfaces`
- `capability_map_surfaces`
- `intake_lifecycle_surfaces`

These are not suitable for blind restoration from the archived concern map. Their archived source/path assumptions no longer match live repo truth:

- `gate.execution.topology.yaml` is no longer truthfully describable as projection-only.
- `ops/capabilities.yaml` is still live authority-like input, but it is absent from the current concern map and lacks an explicit authority marker.
- `intake.lifecycle.contract.yaml` currently declares itself authoritative, which conflicts with the archived projection model.

## Handling of Missing Authority Markers

- `CLAUDE.md` lacks an explicit authority marker even though it acts as a repo-owned thin pointer.
- `ops/capabilities.yaml` lacks an explicit authority-state marker.
- `ops/bindings/gate.execution.topology.yaml` lacks a marker that truthfully explains its mixed authoritative/projection role.

This discovery classifies those as symptoms inside the larger reconciliation seam, not as an isolated marker-only tranche.

## Handling of Entry-Stub Versus Repo-Authority Boundary

- Repo-root `AGENTS.md` is a real governed file path and should be treated as repo-owned entry-surface truth.
- Repo-root `CLAUDE.md` is a real repo entry stub and should stay thin.
- Home-level `~/.claude/CLAUDE.md` remains an adapter target only under `root.authority.contract.yaml`; its status warnings are evidence of adapter-entry drift, not proof that home paths belong in the canonical concern map.

## Dated Timeline

| Date | Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | implementation landed | Widened structural + worker-projection implementation at `11bf71a2` | D411 blocker discovery, decision, election, and implementation closure | Already landed |
| 2026-03-29 | discovery | This discovery artifact with residue table, tranche comparison, and recommendation | Clean synced baseline plus live cross-surface recheck | Blocked if live repo truth no longer matched `11bf71a2` posture |
| 2026-03-29 or next clean landing window | decision | Exact boundary decision for concern-map reconciliation | This discovery artifact committed and pushed | Slips if live authority relationships need further read-only clarification before boundary freeze |
| 2026-03-29 or next clean landing window after decision | election | One explicit authorization result for the bounded reconciliation slice | Discovery + decision artifacts committed and pushed | Slips if the decision boundary remains too broad or mixes repo and home adapter work |
| After election | bounded implementation target if authorized | Repo-owned concern-map reconciliation and marker/source normalization on the elected surfaces only | Election authorizes implementation | Slips if implementation proves capability-definition rewiring or another deferred concern is strictly required |

## Open Questions For Decision Stage

- Should repo-root `AGENTS.md` and `CLAUDE.md` be modeled as their own concern family, or as projections/subordinates under an entry-surface concern sourced elsewhere?
- Should `ops/bindings/platform.control.surfaces.yaml` join the concern map as a standalone family or as part of a broader platform-authority family?
- Should `ops/capabilities.yaml`, `ops/bindings/gate.execution.topology.yaml`, and `ops/bindings/intake.lifecycle.contract.yaml` remain one synchronized family, or split into separate authoritative families with explicit dependencies?
- Does `gate.execution.topology.yaml` need a truthful mixed-surface marker model, or should the authoritative and generated sections eventually be decomposed into separate surfaces?

## Exact Proposed Next Action

- `authoritative_cross_surface_state_synthesis_decision`
