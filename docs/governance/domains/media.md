# media

Canonical domain policy for `media`.

- Authority: `docs/governance/SPINE.md`
- Placement/lifecycle authority: `docs/governance/MEDIA_STORAGE_CONTRACT.md`
- Short lifecycle rules: `docs/governance/MEDIA_STORAGE_LIFECYCLE.md`
- Quality/acquisition authority: `ops/bindings/media.quality.policy.yaml`
- Runtime contracts: `ops/bindings/domains/media.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain media`

Minimal agent reading order:
1. `MEDIA_STORAGE_CONTRACT.md`
2. `MEDIA_STORAGE_LIFECYCLE.md`
3. `ops/bindings/media.quality.policy.yaml`
4. `ops/bindings/media.services.yaml`
5. `ops/bindings/media.path.authority.contract.yaml`

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
