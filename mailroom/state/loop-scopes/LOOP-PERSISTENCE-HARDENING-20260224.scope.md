---
loop_id: LOOP-PERSISTENCE-HARDENING-20260224
created: 2026-02-24
status: active
owner: "@ronny"
scope: infrastructure
priority: high
linked_gaps:
  - GAP-OP-883
  - GAP-OP-884
  - GAP-OP-885
objective: >
  Eliminate silent data-loss risk across all stateful workloads.
  Ensure every stateful service has: (1) persistent host-mounted or named-volume
  storage, (2) backup target in inventory, (3) documented restore path.
---

# Loop Scope: LOOP-PERSISTENCE-HARDENING-20260224

## Objective

Eliminate rebuild data-loss risk by enforcing persistence + backup + restore
coverage for all stateful workloads across all VMs.

## Linked Gaps

- GAP-OP-883 (high): home-vm-100 HA backup stale (114.5h vs 26h threshold)
- GAP-OP-884 (medium): home-lxc-105 Pi-hole backup stale (233.5h vs 168h)
- GAP-OP-885 (medium): app-n8n-workflows backup stale (71.5h vs 26h)

## Findings

### Backup Status (baseline 2026-02-24)
- 20 targets total: 17 OK, 3 degraded
- All 13 shop PVE VMs: OK (vzdump daily, latest within 18h)
- Home site: 2 degraded (vm-100, lxc-105) — likely NFS mount or vzdump job issue
- App-level: n8n-workflows stale — cron job on automation-stack not running

### Stalwart Volume Check
- communications-stack uses named volume `communications-stack_stalwart-data`
  (NOT anonymous) — survives compose recreate. Memory note corrected.

## Required Actions

1. **GAP-OP-883**: Investigate proxmox-home vzdump job + NFS mount health (operator SSH)
2. **GAP-OP-884**: Same root cause as 883 — NFS mount on proxmox-home
3. **GAP-OP-885**: Check n8n-export cron on automation-stack + n8n CLI health
4. All 3 require operator SSH access to diagnose — cannot be fixed from spine alone

## Status

Active — gaps filed with severity and owner. Operator action required for SSH
investigation on home infrastructure.
