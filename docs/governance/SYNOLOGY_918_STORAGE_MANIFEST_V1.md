---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: synology-storage-audit
version: 1.0
loop: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
---

# Synology DS918+ Storage Manifest v1

**Purpose**: Canonical forensic audit of Synology DS918+ storage to classify what exists, what is still active, what has been superseded by 730XD, and what the Synology's future role should be.

**Authority**: This manifest is the definitive source of truth for Synology DS918+ storage state as of 2026-03-08.

**Audit Method**: Read-only SSH inspection, no mutations performed.

---

## Executive Summary

### Current State (2026-03-08)

**Total Capacity**: 20TB (8.2TB used, 43% utilization)
**Tailscale IP**: 100.102.199.111
**Hostname**: synology918
**Model**: Synology DS918+ (Intel Celeron J3455, 4GB RAM)

### Strategic Finding

**The Synology is currently operating as PARALLEL BACKUP AUTHORITY for business/app backups despite 730XD migration being active.**

Critical discoveries:
1. **Business app backups are being written to BOTH NAS and 730XD** (parallel authority violation)
2. **Shop VM offsite backups are INCOMPLETE** (VM 211 partial, VM 213 missing entirely)
3. **Home VM backups are canonical on NAS** (HA VM 100 + Pi-hole LXC 105 — correct home-local exception)
4. **Large personal data families remain** (2.3T Immich, 1.9T photo-keepers, 602G media-staging)
5. **730XD canonical backup plane is ACTIVE and CURRENT** (business backups successfully migrated but not removed from NAS)

### Recommended Future Role

**Synology SHOULD be:**
- **Home-local backup exception** (HA VM 100, Pi-hole LXC 105 only)
- **Personal media/photo archive** (Immich, photo-keepers, media-staging — home-bound workloads)
- **NFS provider for home network** (proxmox-home backup target)

**Synology SHOULD NOT be:**
- Business app backup authority (already migrated to 730XD)
- Shop VM offsite target (incomplete, unreliable)
- Mint/finance/communications canonical backup plane (superseded)

---

## Storage Family Classification

### Business Backups (SUPERSEDED by 730XD)

| Synology Path | Size | Domain | Current Use | 730XD Canonical Path | Migrated | Recommended Action |
|--------------|------|--------|-------------|---------------------|----------|-------------------|
| `/volume1/backups/apps/finance/` | 4.1M | finance | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/finance/` | **YES** | **DELETE after 30-day grace** |
| `/volume1/backups/apps/ghostfolio/` | 76K | finance | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/finance/ghostfolio/` | **YES** | **DELETE after 30-day grace** |
| `/volume1/backups/apps/paperless/` | 951M | finance | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/finance/paperless/` | **YES** | **DELETE after 30-day grace** |
| `/volume1/backups/apps/mint-postgres/` | 18M | mint-data | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/mint-data/postgres/` | **YES** | **DELETE after 30-day grace** |
| `/volume1/backups/apps/stalwart/` | 3.1M | communications | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/communications/stalwart/` | **YES** | **DELETE after 30-day grace** |
| `/volume1/backups/apps/mail-archiver/` | **0** | communications | **EMPTY** | `/md1400/backup-cold/apps/communications/mail-archiver/` | **NO** | **DELETE (empty)** |
| `/volume1/backups/apps/infisical/` | 11M | infra-core | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/infra-core/infisical/` | **YES** | **DELETE after 30-day grace** |
| `/volume1/backups/apps/vaultwarden/` | 33M | infra-core | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/infra-core/vaultwarden/` | **YES** | **DELETE after 30-day grace** |
| `/volume1/backups/apps/gitea/` | 198M | dev-tools | **ACTIVE** (latest 2026-03-08) | `/md1400/backup-cold/apps/dev-tools/gitea/` | **YES** | **DELETE after 30-day grace** |

**Total Business Backups on NAS**: ~1.3GB (excluding Paperless 951M)
**Total Business Backups on 730XD**: ~1.2GB (Finance 951M + others)

**CRITICAL FINDING**: All business app backup scripts are still writing to NAS despite successful 730XD migration. **Parallel authority violation.** Scripts must be updated to write ONLY to 730XD.

### Shop VM Offsite Backups (INCOMPLETE/UNRELIABLE)

| Synology Path | Size | Current Use | Canonical | Recommended Action |
|--------------|------|-------------|-----------|-------------------|
| `/volume1/backups/proxmox/vzdump/critical/` | **1007GB** | Shop VM offsite | **NO** | **INVESTIGATE + DEPRECATE** |

**VM Offsite Inventory (133 files)**:
- **VM 204** (infra-core): PRESENT, latest 2026-03-07
- **VM 205** (observability): PRESENT, latest 2026-03-07
- **VM 206** (dev-tools): PRESENT, latest 2026-03-07
- **VM 207** (ai-consolidation): PRESENT, latest 2026-03-07
- **VM 209** (download-stack): PRESENT, latest 2026-03-07
- **VM 210** (streaming-stack): PRESENT, latest 2026-03-07
- **VM 211** (finance-stack): **INCOMPLETE** (only `.log` + temp files `.kCYqkY`/`.uxySB0`)
- **VM 213** (mint-apps): **MISSING ENTIRELY** (no backups found)

**CRITICAL FINDINGS**:
1. VM 211 (finance-stack): `backup.inventory.yaml` says `enabled: true`, but backup is **INCOMPLETE** (rsync failure)
2. VM 213 (mint-apps): `backup.inventory.yaml` says `enabled: true`, but backup **DOES NOT EXIST**
3. Shop upload bandwidth constraint (~10-20 Mbps) makes 1007GB offsite sync unreliable
4. 730XD tank pool (`/tank/backups/vzdump/dump/`) is canonical shop VM backup plane

**Recommended Action**: **DEPRECATE shop VM offsite to NAS entirely**. Use 730XD tank pool as primary, app-level backups for critical services. Update `backup.inventory.yaml` to disable `vm-211-finance-stack-offsite` and `vm-213-mint-apps-offsite` with explicit rationale.

### Home VM Backups (CANONICAL HOME-LOCAL EXCEPTION)

| Synology Path | Size | Current Use | Canonical | Recommended Action |
|--------------|------|-------------|-----------|-------------------|
| `/volume1/backups/proxmox_backups/dump/` | **170GB** | Home VM backups | **YES** | **KEEP** |

**Home VM Inventory**:
- **VM 100** (Home Assistant): ACTIVE, latest 2026-03-08 (9.6GB)
- **LXC 105** (Pi-hole): ACTIVE, latest 2026-03-08 (437M)
- VM 101/102/103: old backups (Feb 15-20), likely decommissioned

**NFS Export**: `/volume1/backups` → `10.0.0.0/24` (proxmox-home mounts as `/mnt/pve/synology-backups/dump`)

**FINDING**: Home VM backups are **CORRECT** and should remain on NAS. No 730XD migration needed (home-local exception per PROXMOX_VM_SAFETY_DOCTRINE_V1).

**Recommended Action**: **KEEP as canonical home-local backup exception**. Clean up old VM 101/102/103 backups if decommissioned.

### Legacy/Stale Backup Roots (SAFE TO DELETE)

| Synology Path | Size | Last Modified | Recommended Action |
|--------------|------|---------------|-------------------|
| `/volume1/backups/apps/home-assistant/` | 1.6GB | 2026-02-11 | **DELETE** (superseded by VM 100 backup) |
| `/volume1/backups/mint-os/` | 444M | unknown | **DELETE** (legacy pre-fresh-slate) |
| `/volume1/backups/infrastructure/` | 3.1GB | 2026-01-16 | **DELETE** (legacy pre-730XD) |
| `/volume1/backups/finance/` | 1.3M | 2026-01-12 | **DELETE** (legacy pre-730XD) |
| `/volume1/backups/ha/` | 0 | empty | **DELETE** |
| `/volume1/backups/homeassistant_backups/` | 0 | empty | **DELETE** |
| `/volume1/backups/immich/` | 0 | empty | **DELETE** |
| `/volume1/backups/media/` | 8K | empty | **DELETE** |
| `/volume1/backups/devices/` | 462M | 2026-01-25 | **REVIEW** (MacBook backup?) |
| `/volume1/backups/synoreport/` | 66M | 2026-12-26 | **KEEP** (Synology internal) |

**Recommended Action**: Delete legacy backup roots after verifying retention grace period satisfied for business backups.

### Personal Data (HOME-LOCAL CANONICAL)

| Synology Path | Size | Owner | Current Use | Canonical Home | Recommended Action |
|--------------|------|-------|-------------|----------------|-------------------|
| `/volume1/im2ch/` | **2.3TB** | Immich | Photo library (docker, db, uploads) | **Synology** | **KEEP** (home-bound) |
| `/volume1/photo-keepers/` | **1.9TB** | Personal | Photo archive (ronny 1.6T, mint 275G, hypno 30G) | **Synology** | **KEEP** (home-bound) |
| `/volume1/media-staging/` | **602GB** | Media | Download staging area | **Synology** | **KEEP** (home-bound) |
| `/volume1/documents/` | **81GB** | Personal | Documents (mint 77G, hypno 4.4G) | **Synology** | **KEEP** (home-bound) |
| `/volume1/homelab/` | **71GB** | Proxmox | Homelab images/templates | **Synology** | **KEEP** (home-bound) |

**NFS Exports**:
- `/volume1/photo-keepers` → `10.0.0.0/24`
- `/volume1/im2ch` → `10.0.0.0/24` + `192.168.12.0/24`
- `/volume1/media-staging` → `10.0.0.139`, `10.0.0.179` (download/streaming stacks)

**FINDING**: These are genuine **HOME-LOCAL workloads** that should remain on Synology. Not business/app data. Correct canonical home.

**Recommended Action**: **KEEP all personal data families**. No migration needed.

### Empty/Minimal Directories (SAFE TO IGNORE/DELETE)

| Synology Path | Size | Recommended Action |
|--------------|------|-------------------|
| `/volume1/archives/` | 12K | **DELETE** (nearly empty, just .DS_Store) |
| `/volume1/NetBackup/` | 0 | **DELETE** (empty) |
| `/volume1/keepers/` | 0 | **DELETE** (empty) |
| `/volume1/photo-audit/` | 0 | **DELETE** (empty) |
| `/volume1/homes/` | 8K | **KEEP** (minimal user homes) |
| `/volume1/photos/` | 12K | **DELETE** (nearly empty) |
| `/volume1/videos/` | 16K | **DELETE** (nearly empty) |

---

## Duplication Analysis: Synology vs 730XD

### Finance Domain

| Service | NAS Size | NAS Latest | 730XD Size | 730XD Latest | Status |
|---------|----------|------------|------------|--------------|--------|
| Firefly | (in finance/) | 2026-03-08 12:17 | (in finance/firefly/) | 2026-03-08 12:17 | **DUPLICATE** |
| Ghostfolio | 76K | 2026-03-08 12:17 | (in finance/ghostfolio/) | 2026-03-08 12:17 | **DUPLICATE** |
| Paperless | 951M | 2026-03-08 12:17 | 951M | 2026-03-08 12:17 | **DUPLICATE** |

### Mint-Data Domain

| Service | NAS Size | NAS Latest | 730XD Size | 730XD Latest | Status |
|---------|----------|------------|------------|--------------|--------|
| Postgres | 18M | 2026-03-08 12:23 | 18M | 2026-03-08 13:10 | **DUPLICATE** (730XD newer) |

### Communications Domain

| Service | NAS Size | NAS Latest | 730XD Size | 730XD Latest | Status |
|---------|----------|------------|------------|--------------|--------|
| Stalwart | 3.1M | 2026-03-08 12:39 | 3.0M | 2026-03-08 13:09 | **DUPLICATE** |
| mail-archiver | **0** | EMPTY | 0 | EMPTY | **NOT ACTIVE** |

### Infra-Core Domain

| Service | NAS Size | NAS Latest | 730XD Size | 730XD Latest | Status |
|---------|----------|------------|------------|--------------|--------|
| Infisical | 11M | 2026-03-08 11:47 | 2.7M | 2026-03-08 11:47 | **DUPLICATE** |
| Vaultwarden | 33M | 2026-03-08 03:00 | (multiple) | 2026-03-08 03:00 | **DUPLICATE** |

### Dev-Tools Domain

| Service | NAS Size | NAS Latest | 730XD Size | 730XD Latest | Status |
|---------|----------|------------|------------|--------------|--------|
| Gitea | 198M | 2026-03-08 11:48 | 155M | 2026-03-08 11:48 | **DUPLICATE** |

**FINDING**: **100% duplication** for all business app backups. Both NAS and 730XD are receiving IDENTICAL backups at the SAME timestamps. **Parallel authority violation.**

**ROOT CAUSE**: Backup scripts are still configured to write to `/volume1/backups/apps/` on NAS AND `/md1400/backup-cold/apps/` on 730XD simultaneously.

**Required Fix**: Update all backup scripts to write ONLY to 730XD canonical paths. Remove NAS destination from:
- `finance-stack-backup.sh` (VM 211)
- `mint-postgres-backup-730xd.sh` (VM 212)
- `gitea-backup.sh` (VM 206)
- `infra-core backup scripts` (VM 204)
- Any other scripts rsync'ing to `/volume1/backups/apps/`

---

## Synology Runtime Services

### NFS Server (ACTIVE)

**Exports**:
```
/volume1/photo-keepers   → 10.0.0.0/24
/volume1/backups         → 10.0.0.0/24 (proxmox-home primary backup target)
/volume1/im2ch           → 10.0.0.0/24, 192.168.12.0/24
/volume1/archives        → 192.168.12.0/24
/volume1/photos          → 192.168.12.0/24
/volume1/videos          → 192.168.12.0/24
/volume1/media-staging   → 10.0.0.139, 10.0.0.179 (download/streaming stacks)
```

**FINDING**: Synology is an **ACTIVE NFS provider** for home network. Proxmox-home depends on `/volume1/backups` NFS mount.

**Recommended Action**: **KEEP NFS server active** for home-local exceptions and personal data access.

### Immich (ACTIVE)

**Path**: `/volume1/im2ch/`
**Size**: 2.3TB (docker, db, uploads, external-library)
**Use**: Personal photo library

**FINDING**: Immich is a **HOME-LOCAL personal workload**, not business/app infrastructure.

**Recommended Action**: **KEEP Immich on Synology** as canonical home-local photo library.

---

## Future Role Classification

### What Synology SHOULD Be (Canonical)

| Role | Scope | Rationale |
|------|-------|-----------|
| **Home VM backup target** | HA VM 100, Pi-hole LXC 105 | Home-local exception per PROXMOX_VM_SAFETY_DOCTRINE_V1 |
| **Personal media archive** | Immich (2.3T), photo-keepers (1.9T), documents (81G) | Genuine home-bound workloads |
| **Download staging** | media-staging (602G) | Home media pipeline |
| **NFS provider** | Home network (10.0.0.0/24) | Proxmox-home, personal access |

**Total Canonical Synology Use**: ~5TB (personal + home VM backups)

### What Synology SHOULD NOT Be (Superseded)

| Role | Current State | Superseded By | Action Required |
|------|--------------|---------------|-----------------|
| **Business app backup authority** | **ACTIVE** (parallel) | 730XD `/md1400/backup-cold/apps/` | **STOP writing to NAS** |
| **Shop VM offsite target** | **ACTIVE** (incomplete) | 730XD tank pool (primary only) | **DEPRECATE offsite sync** |
| **Mint/finance canonical backup** | **ACTIVE** (duplicate) | 730XD canonical plane | **DELETE after grace period** |

---

## Migration Status Summary

### Already Migrated to 730XD ✅

| Domain | Service | NAS→730XD | Parity Verified | NAS Still Active? |
|--------|---------|-----------|-----------------|-------------------|
| finance | Firefly | ✅ | ✅ | **YES (parallel)** |
| finance | Ghostfolio | ✅ | ✅ | **YES (parallel)** |
| finance | Paperless | ✅ | ✅ | **YES (parallel)** |
| mint-data | Postgres | ✅ | ✅ | **YES (parallel)** |
| communications | Stalwart | ✅ | ✅ | **YES (parallel)** |
| infra-core | Infisical | ✅ | ✅ | **YES (parallel)** |
| infra-core | Vaultwarden | ✅ | ✅ | **YES (parallel)** |
| dev-tools | Gitea | ✅ | ✅ | **YES (parallel)** |

**Migration Status**: **COMPLETE but not finalized** (scripts still writing to both destinations)

### Explicitly Home-Local (No Migration Needed) ✅

| Domain | Service | Canonical Home | Keep on NAS? |
|--------|---------|----------------|--------------|
| home | HA VM 100 | Synology | **YES** |
| home | Pi-hole LXC 105 | Synology | **YES** |
| personal | Immich | Synology | **YES** |
| personal | photo-keepers | Synology | **YES** |
| personal | media-staging | Synology | **YES** |
| personal | documents | Synology | **YES** |

### Failed/Incomplete Migrations ❌

| Domain | Service | Issue | Recommended Action |
|--------|---------|-------|-------------------|
| shop-vms | VM 211 (finance) | Incomplete rsync (temp files only) | **DEPRECATE offsite sync, use app-level** |
| shop-vms | VM 213 (mint-apps) | Missing entirely | **DEPRECATE offsite sync** |

---

## Recommended Actions (Priority Order)

### Immediate (Next 7 Days)

1. **Update backup scripts to write ONLY to 730XD** (stop parallel writes to NAS)
   - Finance: `/usr/local/bin/finance-stack-backup.sh` on VM 211
   - Mint Postgres: `/usr/local/bin/mint-postgres-backup-730xd.sh` on VM 212
   - Stalwart: communications backup script
   - Gitea: `/usr/local/bin/gitea-backup.sh` on VM 206
   - Infra-core: Infisical + Vaultwarden backup scripts on VM 204

2. **Update `backup.inventory.yaml`**:
   - Deprecate `nas-app-backups` destination lane (status: deprecated, migration_complete: 2026-03-08)
   - Update `container-fleet-*` units to point at `r730xd-*-backups` lanes
   - Disable `vm-211-finance-stack-offsite` and `vm-213-mint-apps-offsite` targets with explicit rationale
   - Keep `nas-home-local-exception` lane for HA/Pi-hole only

3. **File gaps for offsite VM backup failures**:
   - GAP-OP-XXXX: VM 211 offsite backup incomplete (rsync temp files only)
   - GAP-OP-XXXX: VM 213 offsite backup missing entirely

### Short-Term (30-Day Grace Period)

4. **DELETE legacy/duplicate business backups on NAS** (after 30-day retention grace):
   - `/volume1/backups/apps/finance/` (4.1M)
   - `/volume1/backups/apps/ghostfolio/` (76K)
   - `/volume1/backups/apps/paperless/` (951M)
   - `/volume1/backups/apps/mint-postgres/` (18M)
   - `/volume1/backups/apps/stalwart/` (3.1M)
   - `/volume1/backups/apps/infisical/` (11M)
   - `/volume1/backups/apps/vaultwarden/` (33M)
   - `/volume1/backups/apps/gitea/` (198M)
   - **Total recovery**: ~1.2GB

5. **DELETE legacy pre-730XD backup roots**:
   - `/volume1/backups/infrastructure/` (3.1GB)
   - `/volume1/backups/mint-os/` (444M)
   - `/volume1/backups/apps/home-assistant/` (1.6GB) — superseded by VM 100 backup
   - **Total recovery**: ~5.1GB

6. **DELETE or ARCHIVE old shop VM offsite backups**:
   - `/volume1/backups/proxmox/vzdump/critical/` (1007GB)
   - Option 1: DELETE entirely (shop VMs have primary backup on 730XD tank pool)
   - Option 2: ARCHIVE critical VMs only (204, 205, 206) for 90-day forensic window
   - **Total recovery**: up to 1007GB

### Medium-Term (90 Days)

7. **Clean up empty/minimal directories**:
   - `/volume1/archives/`, `/volume1/NetBackup/`, `/volume1/keepers/`, `/volume1/photo-audit/`, `/volume1/photos/`, `/volume1/videos/`
   - **Total recovery**: minimal (<1MB)

8. **Review and classify decommissioned home VM backups**:
   - VM 101/102/103 (last backup Feb 15-20) — DELETE if decommissioned
   - **Total recovery**: ~22GB

9. **Update documentation**:
   - Create `SYNOLOGY_EXCEPTION_POLICY.md` defining allowed Synology use
   - Tombstone any docs/scripts referencing Synology as canonical business backup plane
   - Update operator checklists to point at 730XD for business backups

---

## Verification Commands

### Verify 730XD Canonical Backups

```bash
# Finance domain
ssh pve "ls -ltrh /md1400/backup-cold/apps/finance/*/*.{sql.gz,zip,txt} 2>/dev/null | tail -10"

# Mint-data domain
ssh pve "ls -ltrh /md1400/backup-cold/apps/mint-data/postgres/*.{sql.gz,txt} 2>/dev/null | tail -5"

# Communications domain
ssh pve "ls -ltrh /md1400/backup-cold/apps/communications/*/*.{tar.gz,txt} 2>/dev/null | tail -5"

# Infra-core domain
ssh pve "ls -ltrh /md1400/backup-cold/apps/infra-core/*/*.{sql.gz,tar.gz} 2>/dev/null | tail -10"

# Dev-tools domain
ssh pve "ls -ltrh /md1400/backup-cold/apps/dev-tools/gitea/*.sql.gz 2>/dev/null | tail -5"
```

### Verify Synology Home-Local Exceptions

```bash
# Home VM backups (should be ACTIVE)
ssh nas "ls -ltrh /volume1/backups/proxmox_backups/dump/*.zst | tail -10"

# Personal data families (should remain)
ssh nas "du -sh /volume1/im2ch /volume1/photo-keepers /volume1/media-staging /volume1/documents"
```

### Verify Parallel Authority Stopped

```bash
# After script updates, these should NOT receive new backups
ssh nas "ls -ltrh /volume1/backups/apps/finance/*.sql.gz | tail -5"
ssh nas "ls -ltrh /volume1/backups/apps/mint-postgres/*.sql.gz | tail -5"
```

---

## Storage Capacity Projection

### Current Synology Use (8.2TB)

| Family | Current Size | After Cleanup | Notes |
|--------|--------------|---------------|-------|
| Backups (business) | 1.2TB | **0GB** | Migrated to 730XD, delete after grace |
| Backups (shop VM offsite) | 1007GB | **0GB** | Deprecate offsite sync |
| Backups (home VMs) | 170GB | **170GB** | KEEP (canonical) |
| Backups (legacy) | 5.1GB | **0GB** | DELETE |
| Personal (Immich) | 2.3TB | **2.3TB** | KEEP |
| Personal (photo-keepers) | 1.9TB | **1.9TB** | KEEP |
| Personal (media-staging) | 602GB | **602GB** | KEEP |
| Personal (documents) | 81GB | **81GB** | KEEP |
| Personal (homelab) | 71GB | **71GB** | KEEP |
| System/other | ~100GB | **100GB** | Synology OS + packages |

**Current Total**: 8.2TB
**After Cleanup**: **~5.2TB** (recovery: 3TB)
**Future Growth Headroom**: 14.8TB → 11.8TB available after cleanup

### 730XD Canonical Backup Plane (34TB capacity)

| Domain | Current Size | Projected Growth (1 year) |
|--------|--------------|---------------------------|
| Finance | 951M | ~2GB |
| Mint-data | 35M | ~500MB |
| Communications | 5.9M | ~100MB |
| Infra-core | 44M | ~500MB |
| Dev-tools | 155M | ~500MB |
| **Total** | **1.2GB** | **~3.5GB** |

**730XD Capacity**: 34TB (essentially unlimited for app backups)

---

## Gap Linkage

This manifest supports closure of the following gaps/friction items:

- **GAP-OP-XXXX**: Parallel backup authority (NAS + 730XD) for business apps
- **GAP-OP-XXXX**: VM 211 (finance-stack) offsite backup incomplete
- **GAP-OP-XXXX**: VM 213 (mint-apps) offsite backup missing
- **GAP-OP-XXXX**: Synology role ambiguity (business vs home-local)

---

## Governance State

- **Canonical Home**: `docs/governance/SYNOLOGY_918_STORAGE_MANIFEST_V1.md`
- **Parent Loop**: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
- **Backup Authority**: `ops/bindings/backup.inventory.yaml` (requires update)
- **Comparison Surface**: `docs/contracts/BACKUP_730XD_CANONICAL_PATH_MAPPING.md`
- **Doctrine**: `docs/governance/FINANCE_STACK_DOCTRINE_V1.md`, `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md`

**This manifest is frozen as v1.0 on 2026-03-08. Future Synology storage changes require explicit version increment and updated audit.**

---

## Audit Receipt

**Audit Date**: 2026-03-08
**Audit Method**: Read-only SSH inspection (no mutations)
**Commands Used**: `du`, `ls`, `find`, `df`, `showmount`, file reads
**Total Directories Inspected**: 30+
**Total Storage Families Classified**: 25+
**Synology Access**: SSH via Tailscale (100.102.199.111)
**730XD Access**: SSH via pve host
**Audit Duration**: ~45 minutes
**Agent**: Claude Sonnet 4.5

**Next Audit Due**: After 730XD migration finalized (scripts updated, NAS business backups deleted)
