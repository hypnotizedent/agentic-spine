# Backup Plane Consolidation - Executive Summary

> Superseded on 2026-03-08 by the live green backup posture on `main`.
> This document remains as historical execution context only.
> Current canonical truth is in:
> - `ops/bindings/backup.inventory.yaml`
> - `ops/bindings/backup.posture.snapshot.yaml`
> - `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`
> - `docs/governance/SYNOLOGY_918_STORAGE_MANIFEST_V1.md`

**Date**: 2026-03-08
**Loop**: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
**Status**: SUPERSEDED_HISTORICAL_EXECUTION_SUMMARY

## What Was Completed

### ✅ Canonical Path Model Resolved

**Decision**: Use `/md1400/backup-cold/apps/<domain>/<service>/` as canonical backup plane

**Rationale**:
- **34TB capacity** vs 8.4TB (tank/backups)
- **Dedicated backup pool** (md1400/backup-cold ZFS dataset)
- **Room for growth** (128K used, essentially empty)
- **VM backups unchanged** (remain at /tank/backups/vzdump)

**Documentation**: `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`

### ✅ Business Backup Migrations

**Successfully migrated 1.2GB from Synology NAS → 730XD**:

| Domain | Service | Size | Files | Status |
|--------|---------|------|-------|--------|
| Finance | Paperless | 997MB | 9 | ✅ Verified |
| Dev-tools | Gitea | 198MB | 4 | ✅ Verified |
| Infra-core | Vaultwarden | 34.5MB | 21 | ✅ Verified |
| Mint-data | Postgres | 18MB | 2 | ✅ Verified |
| Infra-core | Infisical | 11MB | 8 | ✅ Verified |
| Communications | Stalwart | 3.1MB | 3 | ✅ Verified |
| Finance | Ghostfolio | 69KB | 4 | ✅ Verified |

**Total**: 1.2GB migrated, all file counts verified NAS ↔ 730XD

### ✅ Spine Authority Updates

**New 730XD Destination Lanes Created**:
- `r730xd-finance-backups` → `/md1400/backup-cold/apps/finance`
- `r730xd-mint-backups` → `/md1400/backup-cold/apps/mint-data`
- `r730xd-communications-backups` → `/md1400/backup-cold/apps/communications`
- `r730xd-infra-core-backups` → `/md1400/backup-cold/apps/infra-core`
- `r730xd-dev-tools-backups` → `/md1400/backup-cold/apps/dev-tools`

**Deprecated Lanes**:
- `nas-app-backups` → DEPRECATED (30-day grace period, migration_complete: 2026-03-08)

**New Exception Lane**:
- `nas-home-local-exception` → Synology for Home Assistant VM 100 and Pi-hole LXC 105 only

**Runtime Units Updated** (2/6):
- `container-fleet-infra-core` → r730xd-infra-core-backups ✅
- `container-fleet-finance-stack` → r730xd-finance-backups ✅

### ✅ Physical Infrastructure

**730XD Namespace Created**:
```
/md1400/backup-cold/apps/
├── finance/paperless/ (997MB)
├── finance/ghostfolio/ (69KB)
├── dev-tools/gitea/ (198MB)
├── infra-core/vaultwarden/ (34.5MB)
├── infra-core/infisical/ (11MB)
├── mint-data/postgres/ (18MB)
├── communications/stalwart/ (3.1MB)
└── communications/mail-archiver/ (empty, ready)
```

**Capacity**: 34TB total, 1.2GB used (0.004%)

## What Remains

### 🔄 Runtime Units Need Updates (4 remaining)

Need to update `destination_lane` in `ops/bindings/backup.inventory.yaml`:

1. `container-fleet-mint-data` → r730xd-mint-backups
2. `container-fleet-communications-stack` → r730xd-communications-backups
3. `container-fleet-dev-tools` → r730xd-dev-tools-backups
4. `container-fleet-automation-stack` → (verify if needs update)

**Action**: Complete Edit operations to update these 4 units

### ⚠️ Mail-archiver Stranded Backups

**Issue**: 384GB of historical backups on VM 214 local storage
**Root Cause**: Tailscale SSH policy prevents direct pve ↔ communications-stack rsync
**Current State**: 5 backup files, 384GB total

**Resolution Plan**:
1. Update backup script to write to 730XD canonical path going forward
2. Retain VM 214 backups as disaster recovery archive
3. New backups accumulate in `/md1400/backup-cold/apps/communications/mail-archiver/`
4. Historical backups remain on VM 214 with documented retention policy

**Action**: Deploy updated mail-archiver backup script on VM 214

### 📝 Backup Scripts Need Updates

**Created but not deployed** (in `ops/staged/`):
- `finance-stack-backup-730xd.sh`
- `mint-postgres-backup-730xd.sh`
- `stalwart-backup-730xd.sh`
- `mail-archiver-backup-730xd.sh`
- `infisical-backup.sh`

**Action Required**:
1. Review and test each script
2. Deploy to respective VMs
3. Update cron jobs to use new scripts
4. Run test backup cycles
5. Verify backups appear in 730XD canonical locations

### 🔍 App-Level Backup Targets

**Need to update paths** in `ops/bindings/backup.inventory.yaml`:

Current references to `/volume1/backups/apps/*` should point to:
- `/md1400/backup-cold/apps/finance/*`
- `/md1400/backup-cold/apps/infra-core/*`
- `/md1400/backup-cold/apps/communications/*`
- `/md1400/backup-cold/apps/mint-data/*`
- `/md1400/backup-cold/apps/dev-tools/*`

**Action**: Update `include_paths` in all container-fleet units

### ✅ Synology Exception Scoping

**Home-Local Exceptions** (confirmed valid):
- Home Assistant VM 100 (NAS /volume1/backups/proxmox_backups)
- Pi-hole LXC 105 (NAS /volume1/backups/proxmox_backups)

**Business Backups Deprecated** (30-day grace):
- Finance apps (Firefly, Ghostfolio, Paperless) - migrated to 730XD ✅
- Mint Postgres - migrated to 730XD ✅
- Infra-core (Infisical, Vaultwarden) - migrated to 730XD ✅
- Gitea - migrated to 730XD ✅
- Stalwart - migrated to 730XD ✅

**Cleanup Date**: 2026-04-08 (30 days after migration)

## Verification Commands

### Check 730XD Structure
```bash
ssh pve "ls -R /md1400/backup-cold/apps/"
```

### Verify Migrated Data
```bash
ssh pve "du -sh /md1400/backup-cold/apps/*/*"
```

### Check Capacity
```bash
ssh pve "df -h /md1400/backup-cold"
```

### Verify Backup Inventory
```bash
yq '.model.destination_lanes | keys' ops/bindings/backup.inventory.yaml
```

### Check NAS Status (should show deprecated)
```bash
yq '.model.destination_lanes.nas-app-backups' ops/bindings/backup.inventory.yaml
```

## Next Actions (Priority Order)

1. **Complete inventory updates** (15 min)
   - Update 4 remaining container-fleet destination_lane values
   - Update include_paths to reference 730XD canonical locations

2. **Deploy updated backup scripts** (1-2 hours)
   - Test each script in staging
   - Deploy to production VMs
   - Update cron jobs
   - Run test backup cycles

3. **Verify backup operations** (1 day)
   - Wait for daily backup cycles to complete
   - Verify new backups appear in 730XD canonical locations
   - Check backup.status output

4. **Update documentation** (30 min)
   - Update operator runbooks
   - Document Synology 30-day grace period
   - Create cleanup checklist for 2026-04-08

5. **mail-archiver resolution** (2-4 hours)
   - Deploy updated backup script on VM 214
   - Document VM-local archive retention policy
   - Test offsite sync to 730XD

6. **Final verification** (1 hour)
   - Run backup verify pack
   - Confirm all business backups on 730XD
   - Confirm Synology only has home-local backups
   - Close loop

## Success Criteria

- ✅ Canonical path model resolved and documented
- ✅ Business backup data migrated to 730XD (1.2GB)
- 🔄 Spine inventory updated (2/6 units complete)
- ⏸️ Backup scripts updated and deployed (0/5 deployed)
- ⏸️ Synology reduced to home-local only (30-day grace active)
- ⏸️ mail-archiver stranded backups resolved (plan documented)
- ⏸️ Backup verify pack passes

## Final Status

**Current**: PARTIAL_CONSOLIDATION_WITH_EXACT_REMAINING_EXECUTION

**Estimate to Complete**: 4-6 hours of focused work + 1 day for verification

**Blocking Issues**: None (all execution work can proceed)

**Risk Level**: Low (migrations verified, rollback possible via NAS grace period)

## Reference

- **Loop Scope**: `mailroom/state/loop-scopes/LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308.scope.md`
- **Path Mapping**: `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`
- **Orchestration Packet**: `mailroom/state/orchestration/LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308/packet.yaml`
- **Commit**: 00fdabe7 (feat(backup): execute 730XD canonical backup plane consolidation)
