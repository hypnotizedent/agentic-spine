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

- VMs 100 (Home Assistant), 101 (Immich), 102 (Vaultwarden) have NO backup
- LXCs 103 (download-home), 105 (pihole-home) have NO backup
- All 3 vzdump backup jobs disabled
- Hyper Backup installed but no tasks configured
- No disaster recovery capability for home site

## Blocker Status

**Unblocked as of 2026-02-11.** The prior dependency (`LOOP-PVE-NODE-NAME-FIX-HOME-20260209`) was closed on 2026-02-10 — proxmox-home tooling (`qm list`, `pct list`, `vzdump`) is functional with hostname `pve` by exception policy.

## Success Criteria

1. Hyper Backup configured with backup tasks for all home VMs/LXCs
2. 3-tier backup strategy implemented (P0=critical daily, P1=important daily, P2=weekly)
3. vzdump kept as fallback (manual trigger only)
4. Backup verification procedures documented
5. MINILAB_SSOT.md and BACKUP_GOVERNANCE.md updated

## Phases

### P0: Audit and Planning — COMPLETE
- [x] Document backup state from certification audit
- [x] Confirm blocker resolved (PVE node-name loop closed 2026-02-10)
- [x] Create home backup strategy document (`HOME_BACKUP_STRATEGY.md`)

### P1: Prerequisites — READY
- [ ] Verify NFS connectivity from proxmox-home to NAS (10.0.0.150)
- [ ] Verify/create vzdump storage target on proxmox-home pointing to NAS NFS mount
- [ ] Assess `synology-nas-storage` reference in existing job 1 (missing storage target)

### P2: Enable vzdump Jobs
- [ ] Fix or recreate 3 vzdump jobs with correct storage target
- [ ] Configure tiered schedule: P0 daily 03:00, P1 daily 03:15, P2 weekly
- [ ] Configure retention: keep-last=3

### P3: App-Level Backups
- [ ] Configure Home Assistant backup add-on → NAS `/volume1/backups/homeassistant_backups/`
- [ ] Verify existing HA app-level backup entry in `backup.inventory.yaml` (already enabled)
- [ ] Assess Immich DB backup needs (VM 101 currently STOPPED)

### P4: Backup Inventory Registration
- [ ] Add home vzdump entries to `ops/bindings/backup.inventory.yaml`
- [ ] Generate updated backup calendar (`backup.calendar.generate`)
- [ ] Run `backup.status` to confirm freshness tracking

### P5: Documentation Updates
- [ ] Update MINILAB_SSOT.md with backup configuration
- [ ] Update BACKUP_GOVERNANCE.md to reference home strategy
- [ ] Close loop

## Receipts

- (awaiting execution — planning proposal submitted 2026-02-11)
