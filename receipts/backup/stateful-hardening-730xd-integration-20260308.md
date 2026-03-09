# Stateful Hardening 730XD Integration Receipt

> Superseded on 2026-03-09 by the post-green backup posture and restore-wave proofs.
> This receipt captures the March 8 mid-migration state only.
> Current canonical backup truth is in:
> - `/Users/ronnyworks/code/agentic-spine/ops/bindings/backup.inventory.yaml`
> - `/Users/ronnyworks/code/agentic-spine/ops/bindings/backup.posture.snapshot.yaml`
> - `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/reports/MINT_STATEFUL_SAFETY_BACKUP_POSTURE_20260308.md`
> - `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/reports/restore-drills/FIRST_RESTORE_WAVE_20260309.md`
> - `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/reports/restore-drills/BACKUP_SCRIPT_AUDIT_AND_RESTORE_WAVE_20260309.md`

**Date**: 2026-03-08
**Loop**: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
**Related**: LOOP-PAPERLESS-STATEFUL-BACKUP-DESTRUCTIVE-GUARD-HARDENING-20260308
**Commit**: 8b50c98e

## Objective

Integrate stateful hardening work (Mint Postgres, Finance stack, Communications stack) into the 730XD canonical backup plane consolidation, eliminating parallel NAS-backed backup authority.

## Canonical 730XD Path Model

**Authoritative Source**: `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`

- **Base Path**: `/md1400/backup-cold/apps/<domain>/<service>/`
- **Storage Pool**: `md1400/backup-cold` (34TB ZFS dataset on 730XD)
- **Host**: `pve` (via Tailscale `100.96.211.33`)
- **Access**: SSH as `root` with VM SSH keys added to authorized_keys

### Canonical Paths

```
/md1400/backup-cold/apps/
├── mint-data/
│   └── postgres/
├── finance/
│   ├── firefly/
│   ├── ghostfolio/
│   └── paperless/
└── communications/
    ├── mail-archiver/
    └── stalwart/
```

## Migrations Completed

### 1. Stalwart (Communications Stack) ✅ VERIFIED

**Status**: COMPLETE
**VM**: 214 (communications-stack)
**Runtime Script**: `/usr/local/bin/stalwart-backup.sh`
**730XD Destination**: `/md1400/backup-cold/apps/communications/stalwart/`

**Artifacts Verified on 730XD**:
```
-rw-r--r-- 1 root root  3.0M Mar  8 09:09 stalwart-data-2026-03-08T130936Z.tar.gz
-rw-r--r-- 1 root root   12K Mar  8 09:09 stalwart-config-2026-03-08T130936Z.tar.gz
-rw-r--r-- 1 root root   173 Mar  8 09:09 stalwart-manifest-2026-03-08T130936Z.txt
```

**Backup Success Log**:
```
[2026-03-08T13:09:51+00:00] Stalwart backup SUCCEEDED — 730XD sync verified
[2026-03-08T13:09:51+00:00] 730XD location: pve:/md1400/backup-cold/apps/communications/stalwart
```

**Inventory Updated**:
- Target: `app-stalwart-offsite`
- Old: `host: nas, base_path: /volume1/backups/apps/stalwart`
- New: `host: pve, base_path: /md1400/backup-cold/apps/communications/stalwart`

### 2. Mint Postgres (Mint Data Plane) ✅ VERIFIED

**Status**: COMPLETE
**VM**: 212 (mint-data)
**Runtime Script**: `/usr/local/bin/mint-postgres-backup.sh`
**730XD Destination**: `/md1400/backup-cold/apps/mint-data/postgres/`

**Artifacts Verified on 730XD**:
```
-rw-r--r-- 1 root root  18M Mar  8 09:10 mint-postgres-2026-03-08T131004Z.sql.gz
-rw-r--r-- 1 root root  145 Mar  8 09:10 mint-postgres-manifest-2026-03-08T131004Z.txt
```

**Sanity Guard Passed**:
- Postgres dump: 18M
- DB cluster size: verified
- Table count: verified
- Row count: verified

**Backup Success Log**:
```
[2026-03-08T13:10:20+00:00] mint-postgres backup SUCCEEDED — 730XD sync verified
[2026-03-08T13:10:20+00:00] 730XD location: pve:/md1400/backup-cold/apps/mint-data/postgres
```

**Inventory Updated**:
- Target: `app-mint-postgres`
- Old: `host: nas, base_path: /volume1/backups/apps/mint-postgres`
- New: `host: pve, base_path: /md1400/backup-cold/apps/mint-data/postgres`
- Target: `app-mint-postgres-manifest`
- Old: `host: nas, base_path: /volume1/backups/apps/mint-postgres`
- New: `host: pve, base_path: /md1400/backup-cold/apps/mint-data/postgres`

### 3. Mail-Archiver (Communications Stack) ⏳ IN PROGRESS

**Status**: FIRST SUCCESSFUL RUN IN PROGRESS
**VM**: 214 (communications-stack)
**Runtime Script**: `/usr/local/bin/mail-archiver-backup.sh`
**730XD Destination**: `/md1400/backup-cold/apps/communications/mail-archiver/`

**Database Size**: 128GB
**Expected Duration**: 30-60 minutes
**Started**: 2026-03-08 13:09:59 UTC

**Current Status** (as of 13:15 UTC):
- Phase: Database dump (pg_dump in progress)
- Duration: ~6 minutes elapsed
- ETA: 30-60 minutes total

**Backup Log**:
```
[2026-03-08T13:09:59+00:00] === mail-archiver backup start (730XD offsite) ===
[2026-03-08T13:09:59+00:00] Destination: 730XD canonical backup plane (pve:/md1400/backup-cold/apps/communications/mail-archiver)
```

**Inventory Updated**:
- Target: `app-mail-archiver-offsite`
- Old: `host: nas, base_path: /volume1/backups/apps/mail-archiver`
- New: `host: pve, base_path: /md1400/backup-cold/apps/communications/mail-archiver`
- **NOTE**: First successful run completion pending

## SSH Access Configuration

Added VM SSH keys to PVE authorized_keys for backup sync:

```bash
# VM 212 (mint-data)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKy9Fb2QdCFPpgV3bVe8sriEFPDXxstxh4bpUXjCHI5 mint-data-backup@vm212

# VM 211 (finance-stack)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt0/1Oc9eu3isLDwuJh5Ku/cHZGC/e+49Iw8CKqTWDG finance-stack-backup@vm211

# VM 214 (communications-stack)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfRX1XK1sULobJtD/vKZIXaOfskuVJMo76Xv6kuX/UW ubuntu@communications-stack
```

**PVE Access**: `root@pve` (Tailscale: `root@100.96.211.33`)

## Migrations Deferred

### Finance Stack (VM 211) — PARTIAL

**Reason**: Paperless `document_exporter` timing issue

**Services**:
- ❌ Firefly: Script ready, not deployed (Paperless export blocks full test)
- ❌ Ghostfolio: Script ready, not deployed (Paperless export blocks full test)
- ❌ Paperless: Export timing issue (command completes but zip not immediately available)

**Issue**: The `document_exporter` command returns before the zip file is fully written. Script expects immediate file availability, causing failure.

**Workaround Options**:
1. Add wait loop with polling for export completion
2. Use most recent existing export instead of creating new one
3. Check Paperless task API for completion status

**Current State**:
- Script exists: `/Users/ronnyworks/code/agentic-spine/ops/staged/finance-stack/finance-stack-backup.sh`
- 730XD destination ready: `/md1400/backup-cold/apps/finance/{firefly,ghostfolio,paperless}/`
- SSH access configured
- **NOT deployed to VM 211 runtime**

## Runtime Scripts Deployed

All scripts updated to target 730XD canonical backup plane:

| VM | Script | Destination | Status |
|---|---|---|---|
| 212 | `/usr/local/bin/mint-postgres-backup.sh` | `/md1400/backup-cold/apps/mint-data/postgres/` | ✅ VERIFIED |
| 214 | `/usr/local/bin/stalwart-backup.sh` | `/md1400/backup-cold/apps/communications/stalwart/` | ✅ VERIFIED |
| 214 | `/usr/local/bin/mail-archiver-backup.sh` | `/md1400/backup-cold/apps/communications/mail-archiver/` | ⏳ IN PROGRESS |
| 211 | `/usr/local/bin/finance-stack-backup.sh` | `/md1400/backup-cold/apps/finance/` | ❌ NOT DEPLOYED (Paperless issue) |

## Backup.Inventory.yaml Changes

**File**: `ops/bindings/backup.inventory.yaml`

### Updated Targets (NAS → 730XD)

1. **app-mint-postgres**
   - `host: nas` → `host: pve`
   - `base_path: /volume1/backups/apps/mint-postgres` → `/md1400/backup-cold/apps/mint-data/postgres`
   - Added: "Migrated to 730XD canonical backup plane 2026-03-08"

2. **app-mint-postgres-manifest**
   - `host: nas` → `host: pve`
   - `base_path: /volume1/backups/apps/mint-postgres` → `/md1400/backup-cold/apps/mint-data/postgres`
   - Added: "Migrated to 730XD 2026-03-08"

3. **app-stalwart-offsite**
   - `host: nas` → `host: pve`
   - `base_path: /volume1/backups/apps/stalwart` → `/md1400/backup-cold/apps/communications/stalwart`
   - Added: "Migrated to 730XD canonical backup plane 2026-03-08"

4. **app-mail-archiver-offsite**
   - `host: nas` → `host: pve`
   - `base_path: /volume1/backups/apps/mail-archiver` → `/md1400/backup-cold/apps/communications/mail-archiver`
   - `glob: mail-archiver-*.tar.gz` → `mail-archiver-db-*.sql.gz` (more specific)
   - Added: "Migrated to 730XD canonical backup plane 2026-03-08. First successful run in progress."

## Verification Commands

```bash
# Verify 730XD artifacts
ssh pve "ls -lh /md1400/backup-cold/apps/mint-data/postgres/"
ssh pve "ls -lh /md1400/backup-cold/apps/communications/stalwart/"
ssh pve "ls -lh /md1400/backup-cold/apps/communications/mail-archiver/"

# Check runtime scripts
ssh mint-data "cat /usr/local/bin/mint-postgres-backup.sh | grep OFFSITE_BASE"
ssh communications-stack "cat /usr/local/bin/stalwart-backup.sh | grep OFFSITE_BASE"
ssh communications-stack "cat /usr/local/bin/mail-archiver-backup.sh | grep OFFSITE_BASE"

# Monitor mail-archiver first run
ssh communications-stack "tail -f /tmp/mail-archiver-backup.log"
```

## NAS Retention Strategy

**Grace Period**: 14 days minimum before deleting old NAS copies

**Current NAS State**:
- Mint Postgres: Latest on NAS still exists (retention: 14 days)
- Stalwart: Latest on NAS still exists (retention: 14 days)
- Mail-archiver: Latest on NAS still exists (retention: 14 days)

**Deprecation**: NAS targets should remain enabled until:
1. At least 2 successful 730XD backups completed
2. Restore drill from 730XD backup proven
3. 14-day retention window satisfied

## Next Steps

### Immediate (Required for Completion)

1. **Mail-archiver first run completion** ⏳
   - Monitor backup log until completion (~30-60 min)
   - Verify artifacts on 730XD
   - Update status from "in progress" to "verified"

2. **Finance stack Paperless export fix** 🔧
   - Fix timing issue in `finance-stack-backup.sh`
   - Test backup to 730XD
   - Deploy to VM 211
   - Update inventory targets for Firefly/Ghostfolio/Paperless

### Post-Completion

3. **Restore proof** 📋
   - Test restore from 730XD for at least one service per domain
   - Document restore procedure
   - Update Finance Stack Doctrine v1 compliance

4. **NAS deprecation** 🗑️
   - After 2+ successful 730XD runs + restore proof
   - Disable NAS targets in backup.inventory.yaml
   - Archive final NAS copies
   - Update documentation

5. **Loop closure** ✅
   - Close LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
   - Update LOOP-PAPERLESS-STATEFUL-BACKUP-DESTRUCTIVE-GUARD-HARDENING-20260308

## Final Status

**Current State**: PARTIAL_730XD_INTEGRATION_WITH_EXACT_RUNTIME_PENDING

**Integrated Domains**:
- ✅ Mint Postgres (verified on 730XD)
- ✅ Stalwart (verified on 730XD)
- ⏳ Mail-archiver (first run in progress, ETA 30-60 min)

**Deferred Domains**:
- ❌ Finance (Firefly, Ghostfolio, Paperless) - Paperless export timing issue

**Verification**:
- ✅ Runtime scripts target 730XD
- ✅ Inventory updated for integrated domains
- ✅ 730XD artifacts verified for completed migrations
- ⏳ Mail-archiver completion pending

**Remaining Work**:
1. Monitor mail-archiver completion (~25 min remaining)
2. Fix and deploy finance-stack-backup.sh
3. Restore proof validation
4. NAS deprecation after grace period
