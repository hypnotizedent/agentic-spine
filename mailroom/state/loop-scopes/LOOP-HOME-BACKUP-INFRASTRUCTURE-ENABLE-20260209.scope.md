---
status: active
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE-20260209
severity: high
---

# Loop Scope: LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE-20260209

## Goal

Enable automated backup protection for all home VMs/LXCs. Currently all 3 vzdump backup jobs on proxmox-home are disabled and NAS Hyper Backup has no tasks configured.

## Problem / Current State (2026-02-11)

**vzdump backups now ENABLED.** 3 tiered jobs configured and validated on proxmox-home.
Remaining: P5 documentation updates, then close.

## Blocker Status

**Unblocked as of 2026-02-11.** The prior dependency (`LOOP-PVE-NODE-NAME-FIX-HOME-20260209`) was closed on 2026-02-10 — proxmox-home tooling (`qm list`, `pct list`, `vzdump`) is functional with hostname `pve` by exception policy.

## Success Criteria

1. ~~Hyper Backup configured with backup tasks for all home VMs/LXCs~~ → **Deferred** (vzdump is primary; Hyper Backup for DR in future loop)
2. 3-tier backup strategy implemented (P0=critical daily, P1=important daily, P2=weekly) → **DONE**
3. ~~vzdump kept as fallback (manual trigger only)~~ → **Revised**: vzdump IS the primary method
4. Backup verification procedures documented → **DONE** (HOME_BACKUP_STRATEGY.md)
5. MINILAB_SSOT.md and BACKUP_GOVERNANCE.md updated → **DONE** (this proposal)

## Phases

### P0: Audit and Planning — COMPLETE
- [x] Document backup state from certification audit
- [x] Confirm blocker resolved (PVE node-name loop closed 2026-02-10)
- [x] Create home backup strategy document (`HOME_BACKUP_STRATEGY.md`)

### P1: Prerequisites — COMPLETE
- [x] Verify NFS connectivity from proxmox-home to NAS (10.0.0.150) — ping 0.1ms, NFS active
- [x] Verify vzdump storage target `synology-backups` on proxmox-home — active, 12TB available
- [x] Assess `synology-nas-storage` reference — non-existent storage, job deleted
- [x] Fix storage retention: `keep-all=1` → `keep-last=3`

### P2: Enable vzdump Jobs — COMPLETE
- [x] Deleted broken job `backup-c1ff91b4-5175` (referenced non-existent `synology-nas-storage`)
- [x] Created `backup-home-p0-daily`: VMs 100,102, daily 03:00, keep-last=3, email notify
- [x] Created `backup-home-p1-daily`: LXC 103, daily 03:15, keep-last=3
- [x] Created `backup-home-p2-weekly`: VM 101, LXC 105, weekly Sun 04:00, keep-last=2
- [x] All 3 jobs enabled
- [x] Validation: `vzdump 102` → 3.87GB artifact on NAS confirmed

### P3: App-Level Backups — PARTIAL
- [ ] Configure Home Assistant backup add-on → NAS (deferred to follow-up; vzdump covers VM-level)
- [x] Verify existing HA app-level backup entry in `backup.inventory.yaml` (already enabled, 48h threshold)
- [x] Assess Immich DB backup needs — VM 101 stopped, P2 weekly vzdump covers disk image

### P4: Backup Inventory Registration — COMPLETE
- [x] Add 5 home vzdump entries to `ops/bindings/backup.inventory.yaml`
- [x] Add 3 home schedule events to `ops/bindings/backup.calendar.yaml`
- [ ] Run `backup.calendar.generate` to regenerate ICS (after proposal applied)
- [ ] Run `backup.status` to confirm freshness tracking (after first scheduled run)

### P5: Documentation Updates — COMPLETE
- [x] Update MINILAB_SSOT.md with backup configuration
- [x] Update BACKUP_GOVERNANCE.md to reference home strategy
- [ ] Close loop (after confirming first scheduled run succeeds)

## Receipts

- Planning proposal: `CP-20260211-083735__home-backup-planning-strategy` (applied)
- Enablement proposal: `CP-20260211-085459__home-backup-enablement-infra-and-ssot` (pending apply)
- Baseline receipts:
  - `RCAP-20260211-085217__backup.vzdump.status__Rz73117601` (shop vzdump baseline)
  - `RCAP-20260211-085220__backup.status__R18u817673` (full backup inventory baseline)
- Infra evidence (proxmox-home, 2026-02-11):
  - storage.cfg retention: `keep-all=1` → `keep-last=3`
  - jobs.cfg: 3 stale disabled jobs → 3 tiered enabled jobs
  - Validation artifact: `vzdump-qemu-102-2026_02_11-08_53_32.vma.zst` (3.87GB on NAS)
