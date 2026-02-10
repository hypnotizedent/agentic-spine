---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE-20260209
severity: high
---

# Loop Scope: LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE-20260209

## Goal

Enable automated backup protection for all home VMs/LXCs. Currently all 3 vzdump backup jobs on proxmox-home are disabled and NAS Hyper Backup has no tasks configured.

## Problem / Current State (2026-02-09)

- VMs 100 (Home Assistant), 101 (Immich), 102 (Vaultwarden) have NO backup
- LXCs 103 (download-home), 105 (pihole-home) have NO backup
- All 3 vzdump backup jobs disabled
- Hyper Backup installed but no tasks configured
- No disaster recovery capability for home site

## Success Criteria

1. Hyper Backup configured with backup tasks for all home VMs/LXCs
2. 3-tier backup strategy implemented (P0=critical daily, P1=important daily, P2=weekly)
3. vzdump kept as fallback (manual trigger only)
4. Backup verification procedures documented
5. MINILAB_SSOT.md and BACKUP_GOVERNANCE.md updated

## Phases

### P0: Audit and Planning — IN PROGRESS
- [x] Document backup state from certification audit
- [ ] Create home backup strategy document
- [ ] Plan backup schedule per VM/LXC tier

### P1: Assess Hyper Backup
- Verify Hyper Backup on Synology NAS
- Document capabilities and current config

### P2: Plan Backup Strategy
- Define 3-tier strategy (P0: HA, P1: Vaultwarden, P2: Immich/pihole/download-home)
- Define schedules and retention policies

### P3: Configure Hyper Backup Tasks
- Create backup tasks for each tier
- Configure destinations, schedules, encryption

### P4: Enable vzdump as Fallback
- Keep vzdump jobs but disable scheduled execution
- Document when to use vzdump vs Hyper Backup

### P5: Documentation Updates
- Update MINILAB_SSOT.md with backup strategy
- Update BACKUP_GOVERNANCE.md with home procedures

## Blocked By

- **LOOP-PVE-NODE-NAME-FIX-HOME-20260209** (node name must be fixed first)

## Receipts

- (awaiting execution)
