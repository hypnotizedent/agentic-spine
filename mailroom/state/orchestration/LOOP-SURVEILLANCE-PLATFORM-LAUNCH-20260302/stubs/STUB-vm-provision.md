---
stub_id: STUB-vm-provision
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: resolved
status: cleared
created: "2026-03-04"
cleared_at: "2026-03-05"
cleared_by: "WAVE-SURVEILLANCE-VM-E2E-EXEC-20260305"
owner: "@ronny"
---

# STUB: VM Provisioning for surveillance-stack

## Resolution

VM 215 (surveillance-stack) provisioned and running on PVE.

- Template 9000 cloned to VM 215 on `tank-vms` storage
- 4 cores, 8192MB RAM
- Boot disk: 50GB (scsi0 on tank-vms)
- Data disk: 100GB (virtio1 on tank-vms)
- Static IP: 192.168.1.215/24, GW 192.168.1.1
- SSH keys: PVE root + operator ed25519
- Cloud-init hostname: surveillance-stack
- SSH via PVE jump host: confirmed working

## Evidence

- `qm status 215`: running
- `hostname`: surveillance-stack
- `lsblk`: sda=50GB (boot), vda=100GB (data)
- `df -h /`: 48GB total, 2.1GB used, 46GB available
