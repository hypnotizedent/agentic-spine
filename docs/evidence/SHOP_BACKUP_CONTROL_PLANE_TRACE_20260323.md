# Shop Backup Control-Plane Trace

**Date**: 2026-03-23
**Wave**: LOOP-SHOP-STORAGE-CUTOVER-20260322

## Backup Estate Overview

### Storage Roots

| Root | Path | Size | Role | Status |
|------|------|------|------|--------|
| data-backups | `/data/backups/vzdump/dump/` | 109G | Generator surface | Active (new target) |
| tank-backups | `/tank/backups/vzdump/dump/` | 3.1T | Legacy generator | Draining → data |
| md1400 vzdump | `/md1400/backup-cold/vzdump/pve/` | 2.1T | Canonical cold | Active |
| md1400 apps | `/md1400/backup-cold/apps/` | 1.4T | App-level cold | Active |
| md1400 host | `/md1400/backup-cold/pve-host-config/` | 48K | Host config | Ad-hoc |
| data host | `/data/backups/pve-host-config-20260323/` | 504K | Host config hot | Ad-hoc |

### Runtime Jobs

| Job | Schedule | Target | Status |
|-----|----------|--------|--------|
| vzdump nightly | daily 01:00 | data-backups | Active (11 VMs + 1 LXC) |
| cold-sync | daily 08:30 | md1400 | Active (reads from tank during transition) |
| offsite-sync | manual | NAS via Tailscale | Dead since 2026-03-19 (rsync error 255) |
| archive-smb snapshot | daily 01:05 | md1400 | Active |
| sanoid | every 15m | all pools | Active |

### VM Backup Coverage

| VM | Hostname | vzdump | Cold | App-level | Schedule Tier |
|----|----------|--------|------|-----------|---------------|
| 202 | automation-stack | yes | yes | n/a | canonical_cold |
| 203 | immich | yes | yes | n/a | canonical_cold |
| 204 | infra-core | yes | yes | Infisical+VW drills | minimal_hot |
| 205 | observability | yes | yes | n/a | canonical_cold |
| 206 | dev-tools | yes | yes | Gitea dump | canonical_cold |
| 207 | ai-consolidation | yes | yes | n/a | canonical_cold |
| 211 | finance-stack | yes | yes | Firefly+Paperless+Ghostfolio | minimal_hot |
| 212 | mint-data | yes | yes | pgdump daily | canonical_cold |
| 213 | mint-apps | yes | yes | n/a (stateless) | canonical_cold |
| 214 | communications | yes | yes | mail-archiver daily | canonical_cold |
| 215 | surveillance | yes | yes | n/a | canonical_cold |
| 220 | archive-smb | yes | yes | ZFS snapshots | canonical_cold |
| 200 | docker-host | no | capsule | n/a | decommission_capsule |
| 209 | download-stack | no | residue | n/a | decommission_capsule |
| 210 | streaming-stack | no | residue | n/a | decommission_capsule |

### Authority Files

| File | Role | Status |
|------|------|--------|
| `backup.inventory.yaml` | Root authority | Updated to V3 |
| `backup.schedule.yaml` | Job definitions | 209/210 removed |
| `backup.calendar.yaml` | ICS source | tank→data updated |
| `backup.locality.contract.yaml` | Topology | 209/210 → archive_only |
| `backup.posture.snapshot.yaml` | Generated snapshot | Stale (needs regen) |
| `backup.locality.projected.yaml` | Generated locality | Stale (needs regen) |

### Known Issues

1. **Cold-sync source transition**: reads from tank; switch to data after full nightly (~2026-03-25)
2. **Offsite sync dead**: rsync error 255 since 2026-03-19; no cron entry found
3. **Host config not automated**: ad-hoc only, missing dpkg/apt/sanoid/scripts/cron
4. **VM 214 cold**: only 1 good copy (2026-03-17); newest was partial (deleted)
5. **Mail-archiver cold**: 10 daily dumps at 134G each = 1.3T, no pruning visible
6. **data-backups missing 5 VMs**: 202, 203, 212, 214, 215 not yet on data pool
