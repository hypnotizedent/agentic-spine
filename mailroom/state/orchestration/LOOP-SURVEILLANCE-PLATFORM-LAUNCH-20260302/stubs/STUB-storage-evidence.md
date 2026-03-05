---
stub_id: STUB-storage-evidence
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: blocked_runtime_access
status: parked
created: "2026-03-04"
owner: "@ronny"
depends_on:
  - STUB-vm-provision
---

# STUB: Storage Non-Boot Evidence

## What is blocked

Cannot produce mount/df evidence for non-boot storage until VM 215 is provisioned
with a dedicated data disk.

## Contract Specification

From `surveillance.topology.contract.yaml`:
- Storage tier: `tank-vms` (ZFS zvol)
- Boot disk: 50GB
- Data disk: 100GB
- Data mount: `/mnt/data`
- Recordings: `/mnt/data/frigate/recordings`
- Clips: `/mnt/data/frigate/clips`
- Snapshots: `/mnt/data/frigate/snapshots`
- Frigate DB: `/mnt/data/frigate/frigate.db`

## Required Operator Action

1. After VM provisioned, create ZFS zvol: `pvesm alloc tank 215 vm-215-data 100G`
2. Attach as virtio1 in Proxmox
3. Inside VM: `mkfs.ext4 /dev/vdb && mkdir -p /mnt/data && mount /dev/vdb /mnt/data`
4. Add to fstab: `/dev/vdb /mnt/data ext4 defaults 0 2`
5. Create directories: `mkdir -p /mnt/data/frigate/{recordings,clips,snapshots}`
6. Run `df -h /mnt/data` and capture evidence

## Expected Evidence Format

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vdb        100G  1.0G   99G   1% /mnt/data
```

## Next Action Owner

@ronny (after STUB-vm-provision clears)

## ETA

Immediately after VM provisioning completes.
