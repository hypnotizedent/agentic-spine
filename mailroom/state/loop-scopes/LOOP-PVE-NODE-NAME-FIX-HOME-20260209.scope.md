---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-PVE-NODE-NAME-FIX-HOME-20260209
severity: critical
---

# Loop Scope: LOOP-PVE-NODE-NAME-FIX-HOME-20260209

## Goal

Fix PVE node name mismatch on proxmox-home. Hostname is `proxmox-home` but node configs live under `/etc/pve/nodes/pve/`, breaking all VM/LXC management tools (`qm list`, `pct list`, `pct exec`, vzdump).

## Problem / Current State (2026-02-09)

- PVE node name `pve` but hostname `proxmox-home` — config path mismatch
- Cannot list VMs (`qm list`) or LXCs (`pct list`)
- Cannot execute commands in containers (`pct exec`)
- All 3 vzdump backup jobs disabled and cannot run
- VM 101 (Immich) stopped since 2025-10-19, cannot restart
- GAP-OP-014 tracks this issue

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

- **Blocks:** LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE-20260209

## Receipts

- (awaiting execution)
