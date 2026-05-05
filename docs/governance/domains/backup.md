# backup

Canonical domain policy for `backup`.

- **Doctrine**: `ops/bindings/domains/backup/backup.inventory.yaml` and `ops/bindings/domains/backup/backup.locality.contract.yaml`
- **Operator Checklist**: `backup.status` and `backup.estate.readback.status`
- Authority: `docs/governance/SPINE.md`
- Canonical inventory: `ops/bindings/domains/backup/backup.inventory.yaml`
- Canonical schedule: `ops/bindings/domains/backup/backup.schedule.yaml`
- Canonical calendar projection: `ops/bindings/domains/backup/backup.calendar.yaml`
- Runtime contracts: `ops/bindings/domains/backup.bundle.yaml`
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain backup`

`backup.status` may return `BLOCKED` when a target is present in the canonical
inventory but the current network/auth context cannot probe freshness from this
machine.

## Canonical Model

- `data/backups/vzdump/dump/` is the shop VM/LXC source backup generator plane only (migrated from tank 2026-03-23); it is not shop backup readiness authority.
- `md1400/backups/vm-images/pve/` is the canonical shop VM/LXC restore lane. Non-home VM/LXC backup readback must prove this path, not the generator path.
- Active non-home app/data backup lanes live under restore-intent paths in `md1400/backups/...` (`db-dumps`, `app-data`, `exports`, `configs`, and business file lanes).
- `md1400/backup-cold/...` is legacy/residue unless a target explicitly declares it as retained historical evidence. It is not VM-image authority and not the active app/data target model.
- Synology is the canonical home backup plane for Home Assistant VM `100` and home Pi-hole LXC `105`.
- If the backup plane covers the workload, old app-local backups are debt unless they protect unique data not captured by the backup plane.
- App-local backup scripts, folders, and stale rows are not backup authority by existence. They must be admitted in `backup.inventory.yaml` with a unique-data reason, or they are retired/demoted from readiness.
- Retiring an app-local backup target does not delete retained artifacts. It removes the target from first-class readiness truth.
- Canonical live readback is `backup.status` for admitted enabled targets and `backup.estate.readback.status` for estate subject coverage. Older tranche/admission readbacks are drilldown aids only and must not override these two surfaces.

## Explicit Exclusions

- Large media payloads remain excluded; only media config-state is backed up.
- MinIO duplicate payload backups remain excluded by policy.
- Immich photos stay on their existing photo-backup story and are not duplicated into the shop backup plane.
- Regenerable metadata caches must stay excluded from media-config backups, including:
  - `Radarr` / `Sonarr` / `Lidarr` `MediaCover`
  - `Jellyfin` metadata cache

## Reporting

- Canonical recipient for backup receipts and backup readback alerts: `backups@spine.ronny.works`
- Runtime implementation: Stalwart alias to `alerts@spine.ronny.works`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `backup.calendar.generate` |
| `backup.estate.readback.status` |
| `backup.posture.snapshot.build` |
| `backup.shopfiles.archive.create` |
| `backup.status` |
| `backup.vzdump.mail.policy.set` |
| `backup.vzdump.prune` |
| `backup.vzdump.run` |
| `backup.vzdump.status` |
| `backup.vzdump.vmid.set` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
