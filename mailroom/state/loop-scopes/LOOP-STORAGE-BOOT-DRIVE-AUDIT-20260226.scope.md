---
loop_id: LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226
created: 2026-02-26
status: closed
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

## Steps

- Step 0: Read-only SSH audit (DONE)
- Step 1: File gaps for each violation category (DONE — 7 gaps: GAP-OP-941–947)
- Step 2: Create `infra.storage.placement.policy.yaml` binding (DONE — commit bcaa5bb)
- Step 3: Update VM creation contract with storage step (DONE — GAP-OP-944 closed)
- Step 4: Implement infrastructure-wide drift gate(s) (DONE — D234, GAP-OP-946 closed)
- Step 5: Remediation plan per-VM (DONE — captured in storage placement policy remediation_priority)

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

## Gap Summary

| Gap | Severity | Status | Description |
|-----|----------|--------|-------------|
| GAP-OP-941 | critical | open | VM 211 finance-stack boot drive at 75%, all data on boot |
| GAP-OP-942 | high | **fixed** | Superseded — split into per-VM gaps 952-956 |
| GAP-OP-943 | high | **fixed** | Missing storage placement policy binding |
| GAP-OP-944 | high | **fixed** | VM creation contract missing storage provisioning step |
| GAP-OP-945 | high | **fixed** | VM profile missing data disk configuration |
| GAP-OP-946 | high | **fixed** | Missing infrastructure-wide storage drift gate |
| GAP-OP-947 | medium | **fixed** | Superseded — split into per-VM gaps 957-958 |
| GAP-OP-952 | high | open | VM 204 (infra-core) all data on boot |
| GAP-OP-953 | high | open | VM 205 (observability) all data on boot |
| GAP-OP-954 | medium | open | VM 206 (dev-tools) all data on boot |
| GAP-OP-955 | medium | open | VM 207 (ai-consolidation) all data on boot |
| GAP-OP-956 | critical | open | VM 212 (mint-data) 81% boot, all data on boot (mint terminal) |
| GAP-OP-957 | medium | open | VM 210 (streaming-stack) docker image bloat 54% |
| GAP-OP-958 | low | open | VM 213 (mint-apps) docker image bloat (mint terminal) |

## Audit Summary

Capture-only objective complete. 6/14 gaps fixed (policy + process + superseded bundles). 8 per-VM gaps remain open for runtime remediation. Mint VMs (956, 958) owned by mint terminal.
