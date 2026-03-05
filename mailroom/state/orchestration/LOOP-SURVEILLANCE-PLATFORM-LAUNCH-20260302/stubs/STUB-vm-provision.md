---
stub_id: STUB-vm-provision
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: blocked_runtime_access
status: parked
created: "2026-03-04"
owner: "@ronny"
---

# STUB: VM Provisioning for surveillance-stack

## What is blocked

VM 215 (surveillance-stack) exists in lifecycle bindings as `status: planning` but has not been
provisioned on PVE (Proxmox). The `infra.vm.provision --execute` and `infra.vm.bootstrap --execute`
capabilities require SSH access to PVE hypervisor which was not reachable during this wave.

## Evidence

- `infra.vm.intake.scaffold` dry-run succeeded (VMID 215, 192.168.1.215)
- `infra.vm.intake.scaffold --execute` failed with yq expression error (pre-existing bug, manual entries added)
- VM lifecycle entry added manually to `ops/bindings/vm.lifecycle.yaml`
- SSH target added to `ops/bindings/ssh.targets.yaml`
- Backup target added (disabled) to `ops/bindings/backup.inventory.yaml`

## Required Operator Action

1. SSH to PVE: `ssh root@100.96.211.33`
2. Clone template: `qm clone 9000 215 --name surveillance-stack --full`
3. Configure resources: 4 cores, 8GB RAM, 50GB boot disk
4. Add data disk: `pvesm alloc tank 215 vm-215-data 100G` + attach as virtio1
5. Start VM: `qm start 215`
6. Bootstrap: `./bin/ops cap run infra.vm.bootstrap -- --vmid 215 --execute`
7. Update lifecycle status to `provisioned` then `active`

## Next Action Owner

@ronny (requires PVE console access)

## ETA

When camera outage (LOOP-CAMERA-OUTAGE-20260209) is resolved and PVE is reachable.
