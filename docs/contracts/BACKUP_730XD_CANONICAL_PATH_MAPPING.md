# Canonical 730XD Backup Path Mapping

**Status**: authoritative
**Decision Date**: 2026-03-08
**Loop**: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308

## Path Model Decision

**Canonical Host Path**: `/md1400/backup-cold/apps/<domain>/<service>/`
**Storage Pool**: `md1400/backup-cold` (34TB ZFS dataset)

### Rationale

- **Capacity**: 34TB vs 8.4TB (`tank/backups`)
- **Utilization**: Empty (128K used) vs 33% used (2.8TB)
- **Purpose**: Dedicated backup pool per naming convention
- **Growth**: Massive headroom for app/business backup expansion
- **Cold Copies**: md1400 carries the canonical cold plane for the 730XD/shop environment only

## Storage Architecture

### Two Separate ZFS Pools on 730XD

#### Pool 1: tank/backups (8.4TB)
- **Purpose**: Local hypervisor staging/source for VM vzdump generation
- **Path**: `/tank/backups/vzdump/dump/`
- **Usage**: 2.8TB (33%)
- **Scope**: Proxmox VM/LXC backup source artifacts before md1400 cold promotion

#### Pool 2: md1400/backup-cold (34TB)
- **Purpose**: Canonical cold backup plane
- **Path**: `/md1400/backup-cold/{apps,vzdump,...}`
- **Usage**: 128K (essentially empty)
- **Scope**: Finance, Mint, Communications, Infra-core, Dev-tools, media config-state, n8n, archive-SMB snapshot manifests, promoted shop VM/LXC cold copies

## Canonical App Backup Paths

```
/md1400/backup-cold/apps/
├── finance/
│   ├── firefly/
│   ├── ghostfolio/
│   └── paperless/
├── mint-data/
│   └── postgres/
├── communications/
│   ├── mail-archiver/
│   └── stalwart/
├── infra-core/
│   ├── infisical/
│   └── vaultwarden/
└── dev-tools/
    └── gitea/
```

## Canonical VM/LXC Cold Paths

```
/md1400/backup-cold/vzdump/
└── pve/
```

## Operator-Facing Path

**NO ALIAS**: Use full path `/md1400/backup-cold/apps/` directly
**Rationale**: Avoid confusion, keep path mapping simple

## Migration Impact

### Business Backups → md1400
- Finance (Firefly, Ghostfolio, Paperless): NAS → `/md1400/backup-cold/apps/finance/`
- Mint-data (Postgres): NAS → `/md1400/backup-cold/apps/mint-data/postgres/`
- Communications (mail-archiver): VM-local → `/md1400/backup-cold/apps/communications/mail-archiver/`
- Infra-core (Infisical, Vaultwarden): NAS → `/md1400/backup-cold/apps/infra-core/`
- Dev-tools (Gitea): NAS → `/md1400/backup-cold/apps/dev-tools/gitea/`

### VM/LXC Backups → md1400 Cold Copies
- Shop/local vzdump generation remains on `/tank/backups/vzdump/dump/`
- Canonical cold copies are promoted to `/md1400/backup-cold/vzdump/pve/`
- Home/local vzdump generation and canonical retention remain on Synology-backed storage via proxmox-home

## Explicit Scope / Exclusions

- `md1400` is for the 730XD/shop environment only.
- Home canonical backups stay on Synology (`vm-100`, `lxc-105`).
- Large media payloads are excluded; only media config-state is backed up to `md1400`.
- Duplicate MinIO payload backup is excluded by policy.
- Immich photos remain on their existing photo-backup story, not the shop cold plane.
- Regenerable metadata caches stay excluded from media-config backups, including `MediaCover` and Jellyfin metadata.

## Authority Update Required

`ops/bindings/backup.inventory.yaml` COMPLETED 2026-03-08:
- ✅ Created new destination lanes pointing to `/md1400/backup-cold/apps/<domain>/`
- ✅ Deprecated `nas-app-backups` lane (all business backups migrated to 730XD)
- ✅ Promoted shop VM/LXC cold targets toward md1400 canonical paths

## Verification Commands

```bash
# Verify md1400 structure
ssh pve "ls -R /md1400/backup-cold/apps/"

# Check capacity
ssh pve "df -h | grep md1400"

# Verify promoted VM/LXC cold copies
ssh pve "ls /md1400/backup-cold/vzdump/pve | wc -l"
```

## Implementation Evidence

- Directory structure created: 2026-03-08 08:57 UTC
- Verified capacity: 34TB available
- Pool health: ONLINE (verified via zpool status)
