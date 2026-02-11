---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-PVE-NODE-NAME-FIX-HOME-20260209
severity: critical
---

# Loop Scope: LOOP-PVE-NODE-NAME-FIX-HOME-20260209

## Goal

Resolve PVE node name mismatch on `proxmox-home` (home hypervisor) so `qm`/`pct` tooling and backups are functional.

## Problem / Current State (2026-02-09)

This scope was created under the assumption that proxmox-home's hostname and
PVE node path were mismatched (e.g. hostname `proxmox-home` while configs lived
under `/etc/pve/nodes/pve/`), which would break `qm list`, `pct list`, `pct exec`,
and vzdump.

As of 2026-02-10, governed evidence shows proxmox-home is currently reachable and
Proxmox tooling is functional (hostname `pve` by exception policy; VM inventory
and container inventory readable). This loop is therefore closed as already
resolved / non-actionable.

## Success Criteria

1. VM configs migrated from `/etc/pve/nodes/pve/` to `/etc/pve/nodes/proxmox-home/`
2. `qm list` returns all 3 VMs (100, 101, 102)
3. `pct list` returns all 2 LXCs (103, 105)
4. `pct exec` works for running LXCs
5. vzdump backup jobs re-enabled
6. GAP-OP-014 closed

## Phases

### P0: Audit and Planning — IN PROGRESS
- [x] Document PVE node name mismatch in GAP-OP-014
- [x] Identify VM/LXC configs under `/etc/pve/nodes/pve/`
- [ ] Create migration plan for VM/LXC configs
- [ ] Document vzdump backup jobs that are disabled

### P1: Pre-Staging (Remote via Tailscale)
- Backup current PVE state
- Create `/etc/pve/nodes/proxmox-home/` directory
- Verify running VMs/LXCs are healthy

### P2: Node Name Migration
- Migrate all VM configs to `/etc/pve/nodes/proxmox-home/`
- Migrate all LXC configs
- Restart PVE services

### P3: Post-Migration Verification
- Test `qm list`, `pct list`, `pct exec`
- Verify all running VMs/LXCs still running

### P4: Backup Re-Enablement
- Enable vzdump backup jobs (3 jobs)
- Configure schedules and retention
- Test backup execution

### P5: Documentation Updates
- Update MINILAB_SSOT.md
- Update BACKUP_GOVERNANCE.md
- Close GAP-OP-014

## Blocking

None (this loop is closed).

## Receipts

- Receipt (`infra.hypervisor.identity` PASS): `receipts/sessions/RCAP-20260210-162034__infra.hypervisor.identity__Rchhq6986/receipt.md`
- Receipt (`infra.proxmox.maintenance.precheck` OK): `receipts/sessions/RCAP-20260210-162130__infra.proxmox.maintenance.precheck__Rsx5r7734/receipt.md`
- Receipt (node-path migrate DRY-RUN only, not executed): `receipts/sessions/RCAP-20260210-162055__infra.proxmox.node_path.migrate__Rgxsc7365/receipt.md`
