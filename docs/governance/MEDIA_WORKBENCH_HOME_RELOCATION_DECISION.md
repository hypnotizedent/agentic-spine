# Media Workbench Home Relocation — Decision

status: closed
change_class: new_truth
parent_loop: LOOP-MEDIA-SPLIT-AUTHORITY-CANONICALIZATION-20260322
created: 2026-03-30

## Proposed model

Canonical L3 media product authority relocates from `agentic-spine/ops/bindings/domains/media/` to `workbench/agents/media/`.

### What moves

- 20 live authority binding files → `workbench/agents/media/bindings/`
- 3 archive binding files → `workbench/agents/media/archive/`
- March 29 runtime-first truth documents → `workbench/agents/media/docs/runtime/`

### What stays in spine

- Capability registrations in `ops/capabilities.yaml` (engine entrypoints)
- Routing entries in `ops/bindings/routing.dispatch.yaml` (engine dispatch)
- Drift gates referencing media (engine verification)
- Compatibility projections at the original 23 file paths (live consumer preservation)
- Domain pointer `docs/governance/domains/media.md` (updated to point at workbench)

### Authority boundary after move

- **Workbench canonical**: policy, contracts, inventories, snapshots, runtime docs
- **Spine engine-facing**: capability IDs, routes, gates, compatibility projections
- **Compose/deploy**: remains at `workbench/infra/compose/media-stack/` (unchanged)

## Rationale

1. NORTH_STAR.md: media is a workload, not the platform identity.
2. PLATFORM_LAYER_MODEL.md: media is strong L3 signal.
3. Runtime truth already lives in workbench (compose surface).
4. One operator — workbench avoids the overhead of a fourth repo.
5. HA, Mint, Finance will follow the same pattern later.
