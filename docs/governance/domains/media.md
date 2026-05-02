# media

Canonical domain pointer for `media`.

## Canonical Product Authority Home

**`~/code/projects/media/`**

As of 2026-05-01, canonical L3 media product authority lives in the media
project home. Spine retains engine-facing capability registrations and scoped
readbacks only; it does not retain compatibility symlinks for media bindings.

Relocation: `MEDIA_WORKBENCH_HOME_RELOCATION` (new_truth, ratified 2026-03-30)
Parent loop: `LOOP-MEDIA-SPLIT-AUTHORITY-CANONICALIZATION-20260322`

## Authority Surfaces (project canonical)

- Product bindings: `~/code/projects/media/bindings/` (20 files)
- Product archive: `~/code/projects/media/archive/` (3 files)
- Runtime-first truth: `~/code/projects/media/docs/runtime/`
- Compose/deploy: `~/code/projects/media/compose/` (consolidated 2026-04-14)
- Agent contract: `~/code/projects/media/AGENT.md`

## Spine Engine-Facing Surfaces (retained)

- Capability registrations: `ops/capabilities.yaml` (47 `media.*` IDs, all `implementation_repo: ~/code/projects/media`)
- L3 binding compatibility symlinks: none; consumers read `~/code/projects/media/bindings/` directly when they need product-owned media contracts.
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain media`

## Governance Contracts (spine-owned)

- Current placement authority: `/Users/ronnyworks/code/projects/media/bindings/media.path.authority.contract.yaml`
- Current quality/policy authority: `/Users/ronnyworks/code/projects/media/bindings/media.quality.policy.yaml`
- Historical placement/lifecycle contracts: `/Users/ronnyworks/code/projects/media/bindings/media.path.authority.contract.yaml` and `/Users/ronnyworks/code/projects/media/bindings/media.archive.flow.policy.yaml`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.
Reconciled 2026-04-25 — 47 capabilities re-registered after lean-pass removal.

| Capability |
|---|
| `homarr.config.generate` |
| `media.api.resolve` |
| `media.backup.create` |
| `media.backup.restore` |
| `media.capacity.runway.status` |
| `media.capacity.snapshot.build` |
| `media.config.restore.drill` |
| `media.content.ledger.reconcile` |
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
| `media.radarr.get` |
| `media.radarr.history` |
| `media.radarr.remove` |
| `media.radarr.request` |
| `media.radarr.research` |
| `media.radarr.search` |
| `media.rename.status` |
| `media.scene.rename` |
| `media.service.status` |
| `media.slskd.status` |
| `media.sonarr.get` |
| `media.sonarr.history` |
| `media.sonarr.metrics.today` |
| `media.sonarr.policy.parity` |
| `media.sonarr.request` |
| `media.sonarr.search` |
| `media.soularr.status` |
| `media.stack.restart` |
| `media.status` |
| `media.storage.status` |
| `media.vpn.health` |
| `recyclarr.sync` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
