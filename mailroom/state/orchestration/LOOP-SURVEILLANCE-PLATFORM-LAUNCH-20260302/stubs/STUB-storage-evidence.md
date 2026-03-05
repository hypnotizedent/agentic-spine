---
stub_id: STUB-storage-evidence
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: resolved
status: cleared
created: "2026-03-04"
cleared_at: "2026-03-05"
cleared_by: "WAVE-SURVEILLANCE-VM-E2E-EXEC-20260305"
owner: "@ronny"
depends_on:
  - STUB-vm-provision
---

# STUB: Storage Non-Boot Evidence

## Resolution

Data disk formatted, mounted, and Frigate directory tree created on VM 215.

```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda         98G   40K   93G   1% /mnt/data
```

- Device: `/dev/vda` (virtio1, 100GB ZFS zvol on tank-vms)
- Filesystem: ext4
- Mount: `/mnt/data` (persistent via fstab)
- Directories: `recordings/`, `clips/`, `snapshots/` (owned by UID 1000)
- Boot disk: `/dev/sda` (separate, 50GB)
- Non-boot proof: data disk is vda, boot disk is sda (different devices)
