# Shop Backup Policy Simplification — V3 Model

**Date**: 2026-03-23
**Wave**: LOOP-SHOP-STORAGE-CUTOVER-20260322
**Handoff**: HO-20260323-212310
**Author**: @ronny + Claude

## Summary

Replaced the implicit "back up everything daily, hope for the best" model with a
V3 derived schedule policy where the Spine mechanically determines which VMs need
daily (minimal_hot) vs cold-only (canonical_cold) vzdump protection.

## Key Policy Decision

**The Spine derives the minimal hot set from criteria, not from hardcoded service names.**

A VM enters `minimal_hot` (daily vzdump) when ALL criteria are true:
1. **irreplaceable_small_state** — primary data is user-created and cannot be regenerated
2. **artifact_fits_daily_window** — compressed vzdump artifact < 50G
3. **high_loss_impact** — loss causes estate-wide operational impact or compliance gap

All other active VMs default to `canonical_cold`.

## Derived Assignments

### minimal_hot (daily)
| VM | Hostname | Artifact | Rationale |
|----|----------|----------|-----------|
| 204 | infra-core | ~5G | Infisical secrets + Vaultwarden + Authentik SSO. Loss = estate-wide auth outage. |
| 211 | finance-stack | ~35G | Firefly III transactions + Paperless docs. Loss = financial compliance gap. |

### canonical_cold (default)
| VM | Hostname | Artifact | Why not hot |
|----|----------|----------|-------------|
| 202 | automation-stack | ~19G | Rebuildable from git |
| 203 | immich | ~60G | Exceeds 50G threshold; ZFS snapshots provide PIT protection |
| 205 | observability | ~8G | Telemetry regenerable |
| 206 | dev-tools | ~10G | Gitea repos mirrored externally |
| 207 | ai-consolidation | ~6G | Vectors regenerable from source docs |
| 212 | mint-data | ~202G | Exceeds threshold; has daily pgdump app-level backup |
| 213 | mint-apps | ~10G | Stateless containers |
| 214 | communications | ~971G | Vastly exceeds threshold; has daily mail-archiver backup |
| 215 | surveillance | ~103G | Short retention footage |
| 220 | archive-smb | ~1G | Stateless Samba proxy; ZFS snapshots protect data |

### decommission_capsule (no recurring backup)
| VM | Hostname | Rationale |
|----|----------|-----------|
| 200 | docker-host | Tombstoned 2026-03-06. Single cold capsule retained. |
| 209 | download-stack | Decommissioned 2026-03-23. 30-day hold. |
| 210 | streaming-stack | Decommissioned 2026-03-23. 30-day hold. |

## What Changed

### Authority (9 files, commit 024b978c)
- `backup.inventory.yaml`: V3 vzdump_schedule_policy encoded, 209/210 disabled+decommissioned, removed from runtime unit
- `backup.schedule.yaml`: 209/210 removed from job targets, notes updated
- `backup.calendar.yaml`: descriptions updated (tank→data)
- `backup.locality.contract.yaml`: 209/210 changed to archive_only
- `docs/governance/domains/backup.md`: tank→data reference
- `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`: tank→data pool description
- `infra-vm-intake-scaffold`: backup base path tank→data
- `backup-vzdump-status`: VMID list updated (removed 200/209/210, added 211-215/220), path data-first
- `backup-status`: source comparison path data-first with tank fallback

### PVE Runtime (already applied via SSH)
- `/etc/pve/jobs.cfg`: 209/210 removed from vzdump vmid list
- `/usr/local/bin/vzdump-md1400-cold-sync.sh`: 209/210 removed from QEMU_VMIDS
- `/usr/local/bin/vzdump-offsite-sync.sh`: 209/210 removed from VMIDS
- `/etc/exports`: 209/210 NFS exports removed
- `data-backups` storage: prune-backups keep-last=2 added
- Cold-sync SRC_DIR: reverted to /tank (data doesn't have full coverage yet)

## Phase 2 (deferred)

- Split PVE vzdump job into daily (minimal_hot VMs only) and weekly (canonical_cold)
- Retarget cold-sync from /tank to /data after data-backups has full nightly coverage (~2026-03-25)
- Drain tank/backups entirely once cold-sync reads from data
- Host config recurring backup job (see SHOP_PVE_HOST_RECOVERY_STATUS_20260323.md)

## Destination Topology

```
Canonical cold plane: /md1400/backup-cold/vzdump/pve/  (recovery authority)
Generator surface:    /data/backups/vzdump/dump/        (transitioning from /tank)
App-level cold:       /md1400/backup-cold/apps/<domain>/ (per-domain)
Home cold:            nas:/volume1/backups/proxmox_backups/dump/
```
