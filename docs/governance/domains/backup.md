# backup

Canonical domain policy for `backup`.

- **Doctrine**: `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md` (canonical VM primary/offsite/app-level/restore-proof law)
- **Operator Checklist**: `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md` (operator checklist for VM protection and offsite exceptions)
- Authority: `docs/governance/SPINE.md`
- Canonical inventory: `ops/bindings/backup.inventory.yaml`
- Runtime contracts: `ops/bindings/domains/backup.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain backup`

`backup.status` may return `BLOCKED` when a target is present in the canonical
inventory but the current network/auth context cannot probe freshness from this
machine.

## Canonical Model

- `tank/backups/vzdump/dump/` is the shop VM/LXC source backup plane.
- `md1400/backup-cold/...` is the shop cold backup plane for app/state and promoted shop VM/LXC copies.
- Synology is the canonical home backup plane for Home Assistant VM `100` and home Pi-hole LXC `105`.

## Explicit Exclusions

- Large media payloads remain excluded; only media config-state is backed up.
- MinIO duplicate payload backups remain excluded by policy.
- Immich photos stay on their existing photo-backup story and are not duplicated into the shop backup plane.
- Regenerable metadata caches must stay excluded from media-config backups, including:
  - `Radarr` / `Sonarr` / `Lidarr` `MediaCover`
  - `Jellyfin` metadata cache

## Reporting

- Canonical recipient for backup receipts and backup-monitor alerts: `backups@spine.ronny.works`
- Runtime implementation: Stalwart alias to `alerts@spine.ronny.works`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `backup.calendar.generate` |
| `backup.monitor` |
| `backup.posture.snapshot.build` |
| `backup.status` |
| `backup.vzdump.mail.policy.set` |
| `backup.vzdump.prune` |
| `backup.vzdump.run` |
| `backup.vzdump.status` |
| `backup.vzdump.vmid.set` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
