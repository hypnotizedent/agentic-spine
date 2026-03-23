# Shop Backup Control-Plane Command Log

**Date**: 2026-03-23
**Wave**: LOOP-SHOP-STORAGE-CUTOVER-20260322

## PVE Runtime Commands Executed

### Remove VMs 209/210 from vzdump job
```bash
# Via governed capability
./bin/ops cap run backup.vzdump.vmid.set -- --remove 209,210 --execute
# Result: vmid list changed from 202,203,204,205,206,207,209,210,211,212,213,214,215,220
#                              to 202,203,204,205,206,207,211,212,213,214,215,220
```

### Remove VMs 209/210 from offsite sync
```bash
ssh root@pve "sed -i 's/VMIDS=\"204 205 206 207 209 210 211 213\"/VMIDS=\"204 205 206 207 211 213\"/' /usr/local/bin/vzdump-offsite-sync.sh"
```

### Remove VMs 209/210 from cold-sync VMID array
```bash
ssh root@pve "sed -i 's/QEMU_VMIDS=(202 203 204 205 206 207 209 210 211 212 213 214 215)/QEMU_VMIDS=(202 203 204 205 206 207 211 212 213 214 215)/' /usr/local/bin/vzdump-md1400-cold-sync.sh"
```

### Remove 209/210 NFS exports
```bash
ssh root@pve "cat > /etc/exports << 'EXPORTS'
/tank/immich 192.168.1.203/32(rw,sync,no_subtree_check,no_root_squash)
EXPORTS
exportfs -ra"
```

### Add prune policy to data-backups
```bash
ssh root@pve "pvesm set data-backups --prune-backups keep-last=2"
```

### Revert cold-sync source to tank
```bash
ssh root@pve "sed -i 's|SRC_DIR=\"/data/backups/vzdump/dump\"|SRC_DIR=\"/tank/backups/vzdump/dump\"|' /usr/local/bin/vzdump-md1400-cold-sync.sh"
# Reason: data-backups only has 8 of 11 active VMs; tank has full set
```

### Delete corrupt VM 214 partial on md1400
```bash
ssh root@pve "rm /md1400/backup-cold/vzdump/pve/vzdump-qemu-214-2026_03_23-03_27_29.vma.zst"
# 550G partial from interrupted cold-sync
```

### Delete oldest pre-move VM 214 cold copy
```bash
ssh root@pve "rm /md1400/backup-cold/vzdump/pve/vzdump-qemu-214-2026_03_16-*.vma.zst"
# 972G, freed 1.5T on md1400
```

## ZFS Destroy Commands (earlier in session)

```bash
# Old tank zvols from completed VM moves (5.4T freed)
zfs destroy -r tank/vms/vm-214-disk-0     # 4.1T (communications)
zfs destroy -r tank/vms/vm-212-data        # 578G (mint-data)
zfs destroy -r tank/vms/vm-202-disk-0      # 144G (automation)
zfs destroy -r tank/vms/vm-215-disk-0      # }
zfs destroy -r tank/vms/vm-215-disk-1      # } 601G total (surveillance)
zfs destroy -r tank/docker/subvol-220-disk-0  # 717M (archive-smb)

# Stale VM 9207 zvol on data pool
zfs destroy -r data/vms/vm-9207-disk-0     # 203G

# Decommissioned 209/210 docker datasets
zfs destroy -r tank/docker/download-stack   # 87G
zfs destroy -r tank/docker/streaming-stack  # 56G
# Plus 32 tank/docker parent snapshots (403G)
```

## Governance File Changes

See commit `024b978c` on branch `codex/wave-backup-simplification-20260323`.
