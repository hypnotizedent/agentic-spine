---
loop_id: LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226
created: 2026-02-26
status: active
owner: "@ronny"
scope: infrastructure
priority: high
objective: Infrastructure-wide read-only audit of all VM container storage mounts to identify boot-drive violations, establish storage placement policy, and add drift gates to prevent recurrence.
related_loops:
  - LOOP-STORAGE-BIND-MOUNT-DRIFT-GATE-20260226
absorbed_loops:
  - LOOP-STORAGE-BIND-MOUNT-DRIFT-GATE-20260226
---

# Loop Scope: LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226

## Objective

Infrastructure-wide read-only audit of all VM container storage mounts. Identify every container storing persistent data on boot drives, establish what legitimately belongs on boot drives vs dedicated storage, create storage placement policy, and add drift gates.

## Context

Containers/VMs repeatedly get default-setup to boot drives because:
1. `spine-ready-v1` profile provisions only a boot disk on `local-lvm`
2. No storage placement policy binding exists
3. Docker defaults volumes to `/var/lib/docker/volumes/` on boot
4. VM creation contract has no storage provisioning step
5. Only media VMs (209/210) were explicitly set up with NFS mounts

## Audit Scope (13 active shop VMs + 2 home)

### CRITICAL: VM 211 (finance-stack) — 75% boot, ALL data on boot
### HIGH: VMs 204, 205, 206, 207, 212 — ALL service data on boot
### MEDIUM: VMs 210, 202, 214 — partial issues
### LOW: VMs 200, 209, 213, 100, 105 — managed correctly

## Phases

- P0: Read-only SSH audit (complete)
- P1: File gaps for each violation category
- P2: Create `infra.storage.placement.policy.yaml` binding
- P3: Update VM creation contract with storage step
- P4: Implement infrastructure-wide drift gate(s)
- P5: Remediation plan per-VM (capture-only, no runtime changes this loop)

## Success Criteria

- All violations documented with gap entries
- Storage placement policy binding created
- VM creation contract updated
- At least one infrastructure-wide drift gate added
- Remediation roadmap captured (execution in separate loops)

## Definition Of Done

- All gaps filed and linked to this loop
- Policy binding exists at `ops/bindings/infra.storage.placement.policy.yaml`
- D234+ gate enforces storage placement
- VM_CREATION_CONTRACT.md updated with storage step
- No runtime changes (capture-only audit)
