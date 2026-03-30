# media

Canonical domain pointer for `media`.

## Canonical Product Authority Home

**`~/code/workbench/agents/media/`**

As of 2026-03-30, canonical L3 media product authority lives in the workbench media home.
Spine retains engine-facing registrations, routing, gates, and compatibility projections only.

Relocation: `MEDIA_WORKBENCH_HOME_RELOCATION` (new_truth, ratified 2026-03-30)
Parent loop: `LOOP-MEDIA-SPLIT-AUTHORITY-CANONICALIZATION-20260322`

## Authority Surfaces (workbench canonical)

- Product bindings: `~/code/workbench/agents/media/bindings/` (20 files)
- Product archive: `~/code/workbench/agents/media/archive/` (3 files)
- Runtime-first truth: `~/code/workbench/agents/media/docs/runtime/`
- Compose/deploy: `~/code/workbench/infra/compose/media-stack/docker-compose.yml`
- Agent contract: `~/code/workbench/agents/media/AGENT.md`
- Boundary: `~/code/workbench/agents/media/docs/BOUNDARY.md`

## Spine Engine-Facing Surfaces (retained)

- Capability registrations: `ops/capabilities.yaml` (all `media.*` IDs)
- Routing: `ops/bindings/routing.dispatch.yaml`
- Compatibility projections: `ops/bindings/domains/media/` (23 files, marked do-not-edit-here)
- Verify entrypoint: `./bin/ops cap run verify.run -- domain media`

## Governance Contracts (spine-owned)

- Placement/lifecycle: `docs/governance/MEDIA_STORAGE_CONTRACT.md`
- Short lifecycle rules: `docs/governance/MEDIA_STORAGE_LIFECYCLE.md`
- Relocation discovery: `docs/governance/MEDIA_WORKBENCH_HOME_RELOCATION_DISCOVERY.md`
- Relocation decision: `docs/governance/MEDIA_WORKBENCH_HOME_RELOCATION_DECISION.md`
- Relocation election: `docs/governance/MEDIA_WORKBENCH_HOME_RELOCATION_ELECTION.md`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `homarr.config.generate` |
| `media.api.resolve` |
| `media.backup.create` |
| `media.backup.restore` |
| `media.capacity.runway.status` |
| `media.capacity.snapshot.build` |
| `media.config.restore.drill` |
| `media.content.snapshot.refresh` |
| `media.download.canary.check` |
| `media.downloads.bloat.status` |
| `media.duplicate.scan` |
| `media.e2e.verify` |
| `media.health.check` |
| `media.import.cli` |
| `media.library.junk.audit` |
| `media.metrics.today` |
| `media.music.metrics.today` |
| `media.nfs.verify` |
| `media.pipeline.trace` |
| `media.qbittorrent.status` |
| `media.quarantine.review` |
| `media.queue.reconcile` |
| `media.queue.reconcile.lidarr` |
| `media.queue.reconcile.sonarr` |
| `media.rename.status` |
| `media.scene.rename` |
| `media.service.status` |
| `media.slskd.status` |
| `media.sonarr.metrics.today` |
| `media.sonarr.policy.parity` |
| `media.soularr.status` |
| `media.stack.restart` |
| `media.status` |
| `media.storage.status` |
| `media.vpn.health` |
| `recyclarr.sync` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
