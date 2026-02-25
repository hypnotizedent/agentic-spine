---
loop_id: LOOP-PERSISTENCE-HARDENING-20260224
created: 2026-02-24
status: closed
closed: 2026-02-24
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

## Outcome

**CLOSED** — All 3 linked gaps resolved. backup.status: 20/20 OK, 0 degraded.

### Root Cause Analysis

**proxmox-home backup staleness (GAP-OP-883, GAP-OP-884):**
- pvescheduler running since Feb 7 with 17.9G memory (leak), stopped scheduling
  vzdump jobs after Feb 20
- Storage mount (synology-backups NFS) was healthy throughout
- vzdump jobs were enabled and correctly configured
- Fix: restart pvescheduler (memory freed, scheduling resumed) + trigger
  immediate backup for VM 100 and LXC 105
- LXC 105 additionally needed `--tmpdir /var/tmp` to work around NFS
  user-namespace tar permission issue (same tmpdir the weekly job config uses)

**n8n snapshot staleness (GAP-OP-885):**
- Cron was already healthy at time of investigation (0.9h age)
- Original staleness was transient (cron recovered on its own)
- However, n8n workflow count dropped from 35 to 1 — separate issue filed as
  GAP-OP-886 (high severity, standalone)

### Gaps Resolved

| Gap | Severity | Resolution |
|-----|----------|------------|
| GAP-OP-883 | high | pvescheduler restart + fresh VM100 backup (8.06GB) |
| GAP-OP-884 | medium | LXC tmpdir fix + fresh LXC105 backup (371MB) |
| GAP-OP-885 | medium | Cron already healthy (0.9h age) |

### New Capability Created

`home.backup.vzdump.run` — governed vzdump trigger for proxmox-home:
- Dry-run default, `--execute` required for mutation
- Auto-detects LXC containers and adds `--tmpdir /var/tmp`
- `--restart-scheduler` flag for pvescheduler recovery
- Registered in capabilities.yaml + capability_map.yaml

### Spillover Gap

GAP-OP-886 (high): n8n workflow count dropped from 35 to 1 after apparent
rebuild on Feb 22-23. Snapshots from Feb 17-22 contain full 35-workflow set
for restoration. Not linked to this loop — standalone.

## Linked Gaps

- GAP-OP-883 (high): FIXED — home-vm-100 HA backup stale
- GAP-OP-884 (medium): FIXED — home-lxc-105 Pi-hole backup stale
- GAP-OP-885 (medium): FIXED — app-n8n-workflows backup stale

## Findings

### Backup Status (baseline 2026-02-24)
- 20 targets total: 17 OK, 3 degraded
- All 13 shop PVE VMs: OK (vzdump daily, latest within 18h)
- Home site: 2 degraded (vm-100, lxc-105) — pvescheduler stuck
- App-level: n8n-workflows stale — transient, self-recovered

### Stalwart Volume Check
- communications-stack uses named volume `communications-stack_stalwart-data`
  (NOT anonymous) — survives compose recreate. Memory note corrected.

### Final State
- backup.status: 20/20 OK, 0 degraded
- pvescheduler restarted with fresh memory footprint
- Future daily/weekly vzdump jobs will resume on schedule
