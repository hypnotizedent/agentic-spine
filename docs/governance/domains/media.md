# media

Canonical domain policy for `media`.

- Authority: `docs/governance/SPINE.md`
- Placement/lifecycle authority: `docs/governance/MEDIA_STORAGE_CONTRACT.md`
- Short lifecycle rules: `docs/governance/MEDIA_STORAGE_LIFECYCLE.md`
- Runtime contracts: `ops/bindings/domains/media.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain media`

Minimal agent reading order:
1. `MEDIA_STORAGE_CONTRACT.md`
2. `MEDIA_STORAGE_LIFECYCLE.md`
3. `ops/bindings/media.services.yaml`
4. `ops/bindings/media.path.authority.contract.yaml`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `homarr.config.generate` |
| `media-content-snapshot-refresh` |
| `media.backup.create` |
| `media.capacity.runway.status` |
| `media.capacity.snapshot.build` |
| `media.config.restore.drill` |
| `media.e2e.verify` |
| `media.health.check` |
| `media.metrics.today` |
| `media.music.metrics.today` |
| `media.nfs.verify` |
| `media.pipeline.trace` |
| `media.qbittorrent.status` |
| `media.queue.reconcile` |
| `media.service.status` |
| `media.slskd.status` |
| `media.sonarr.metrics.today` |
| `media.soularr.status` |
| `media.stack.restart` |
| `media.status` |
| `media.storage.status` |
| `media.vpn.health` |
| `recyclarr.sync` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
