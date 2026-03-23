# Shop Backup Runtime Alignment

**Date**: 2026-03-23
**Wave**: LOOP-SHOP-STORAGE-CUTOVER-20260322

## Runtime vs Authority Alignment Check

### vzdump Job VMIDs

| Source | VMIDs | Match? |
|--------|-------|--------|
| PVE jobs.cfg (runtime) | 202,203,204,205,206,207,211,212,213,214,215,220 | - |
| backup.inventory.yaml runtime_unit (authority) | 202,203,204,205,206,207,211,212,213,214,215,220 | YES |
| backup.schedule.yaml job targets (authority) | same (209/210 commented out) | YES |

### Cold-Sync VMIDs

| Source | VMIDs | Match? |
|--------|-------|--------|
| vzdump-md1400-cold-sync.sh QEMU_VMIDS (runtime) | 202,203,204,205,206,207,211,212,213,214,215 | - |
| vzdump-md1400-cold-sync.sh LXC_VMIDS (runtime) | 220 | - |
| backup.inventory.yaml enabled targets (authority) | same set (209/210 disabled) | YES |

### Offsite Sync VMIDs

| Source | VMIDs | Match? |
|--------|-------|--------|
| vzdump-offsite-sync.sh VMIDS (runtime) | 204,205,206,207,211,213 | - |
| Note: offsite sync is dead (rsync error 255 since 2026-03-19) | n/a | DEAD |

### NFS Exports

| Source | Exports | Match? |
|--------|---------|--------|
| /etc/exports (runtime) | Immich only (192.168.1.203) | - |
| infra.storage.placement.policy.yaml | Only immich needs NFS | YES |

### VMs 209/210 Decommission Status

| Surface | 209 Status | 210 Status |
|---------|-----------|-----------|
| PVE jobs.cfg | Removed | Removed |
| Cold-sync VMIDS | Removed | Removed |
| Offsite-sync VMIDS | Removed | Removed |
| NFS exports | Removed | Removed |
| backup.inventory.yaml | enabled: false, decommissioned | enabled: false, decommissioned |
| backup.schedule.yaml | Commented out | Commented out |
| backup.locality.contract.yaml | archive_only | archive_only |
| vm.lifecycle.yaml | status: decommissioned | status: decommissioned |
| infra.storage.placement.policy.yaml | placement_status: tombstoned | placement_status: tombstoned |

**Result: Runtime matches authority across all surfaces for 209/210 decommission.**

## data-backups Prune Policy

| Surface | Value | Match? |
|---------|-------|--------|
| PVE storage.cfg (runtime) | prune-backups keep-last=2 | - |
| backup.inventory.yaml pve-vzdump-primary lane | max_file_count: 120 | Compatible |

## Remaining Misalignments

1. **Cold-sync source**: script reads from `/tank`, authority says generator is `/data` — intentional transition
2. **Offsite sync**: dead runtime, still referenced in `service.data.lifecycle.registry.yaml` — needs cleanup
3. **Generated projections**: `backup.posture.snapshot.yaml` and `shop.storage.map.yaml` still show tank paths — need regeneration
