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
- **VM Backups**: Remain at `/tank/backups/vzdump/dump/` (already canonical)

## Storage Architecture

### Two Separate ZFS Pools on 730XD

#### Pool 1: tank/backups (8.4TB)
- **Purpose**: VM vzdump backups (primary)
- **Path**: `/tank/backups/vzdump/dump/`
- **Usage**: 2.8TB (33%)
- **Scope**: Proxmox VM/LXC backups

#### Pool 2: md1400/backup-cold (34TB)
- **Purpose**: App-level business backups (canonical)
- **Path**: `/md1400/backup-cold/apps/<domain>/<service>/`
- **Usage**: 128K (essentially empty)
- **Scope**: Finance, Mint, Communications, Infra-core, Dev-tools

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

### VM Backups → tank (NO CHANGE)
- All shop VMs continue using `/tank/backups/vzdump/dump/`
- Proxmox vzdump jobs unchanged

### Home Backups → Synology (EXCEPTION)
- Home Assistant VM 100: NAS (permanent home-local exception, HA ONLY)
- ~~Pi-hole LXC 105: NAS~~ REMOVED 2026-03-08 — migrated to pve-vzdump-primary

## Authority Update Required

`ops/bindings/backup.inventory.yaml` COMPLETED 2026-03-08:
- ✅ Created new destination lanes pointing to `/md1400/backup-cold/apps/<domain>/`
- ✅ Deprecated `nas-app-backups` lane
- ✅ Updated `nas-home-local-exception` lane for HA ONLY (Pi-hole removed)

## Verification Commands

```bash
# Verify md1400 structure
ssh pve "ls -R /md1400/backup-cold/apps/"

# Check capacity
ssh pve "df -h | grep md1400"

# Verify tank VM backups unchanged
ssh pve "ls /tank/backups/vzdump/dump/ | wc -l"
```

## Implementation Evidence

- Directory structure created: 2026-03-08 08:57 UTC
- Verified capacity: 34TB available
- Pool health: ONLINE (verified via zpool status)
