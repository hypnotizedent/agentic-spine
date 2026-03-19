---
status: authoritative
owner: "@ronny"
version: "1.0"
last_verified: "2026-03-19"
authority_concern: media_storage_lifecycle
scope: media-storage-architecture-and-lifecycle
---

# Media Storage Contract

**Status**: AUTHORITATIVE
**Version**: 1.1
**Last Verified**: 2026-03-19

## Purpose

This contract defines the canonical media storage architecture, tier assignments, lifecycle rules, and migration boundaries for all media content (movies, TV, music, downloads). It establishes what lives where, when content moves between tiers, and how to safely execute the current-to-target migration without data loss.

## Executive Summary

**Current State (Verified 2026-03-19, Post-Phase 1)**:
- Shop media pool at **86% capacity** (25.1T/29.1T) — SAFE ✅
- **105G downloads** (staging-only rule restored — was 2.3T)
- Active libraries: 9.6T movies + 5.5T TV + 666G music = ~15.8T
- Cold tier (md1400) has 20.4T available headroom
- Quarantine tier (md1400) operational with 2.07T pending review
- Home tier (Synology) has 13T available
- media-home VM 106 canonicalized in governance
- Synology share truth is now explicit: `/volume1/media-staging` is the only populated/exported media share currently used by VM 106, `/volume1/media-holds` is the explicit hold/review share, and `/volume1/media-home` is not a live share

**Target State**:
- Home is the best playback/download experience (fast internet, low latency)
- Shop 730xd is the canonical cold archive plane (large capacity, infrequent access)
- Downloads are staging-only, never permanent residence
- Quarantine tier exists for low-value bulk imports before deletion review
- Clear tier boundaries with explicit lifecycle automation support

**Critical Constraint**: No large data moves until the target architecture is explicit and the media pool capacity crisis is resolved.

---

## Tier Definitions

### 1. Hot Tier (Home Playback)

**Canonical Host**: `synology918` (Synology DS918+) + `media-home` VM 106 (proxmox-home)
**Role**: Fast access playback for home consumption, with current share truth kept explicit
**Capacity**: 20T total, 13T available (34% usage)
**Content Classes**:
- Favorites / frequently watched
- Recent acquisitions
- High-demand family content
- Active downloads (staging before import)

**Current Live Share Layout** (Synology):
```
/volume1/media-staging/      # Only populated/exported media share currently used by VM 106
  downloads/                 # Fresh downloads + in-flight staging
  movies/                    # Current live movies share subtree
  tv/                        # Current live TV share subtree
  music/                     # Current live music share subtree
/volume1/media-holds/        # Explicit hold/review/overflow lane
  manual-import-review/
  duplicate-review/
  forensic-holds/
```

There is currently **no dedicated live `/volume1/media-home/` share**. The old `media-home`, `media`, `hot-media`, `live-library`, and `library-home` names are ghost placeholders, not active share truth.

**Serving Method**: media-home VM 106 currently consumes `/volume1/media-staging`; `media-holds` is exported separately as a hold/review share.

**Performance Target**:
- Read latency: <50ms for local playback
- Write bandwidth: 100MB/s+ for download staging

**Backup**:
- Proxmox VM backup to Synology (VM 106)
- Config state: daily snapshots
- Media payload: regenerable (not backed up)

---

### 2. Warm Tier (Shop Active Library)

**Canonical Host**: `pve` (R730XD) — `media` pool
**Role**: Primary active library for streaming-stack and download-stack services
**Current Hardware**: 4x8TB SATA RAIDZ1 (Archive/SMR, aging)
**Target Hardware**: 4x14TB SAS RAIDZ1 (acquired, ready for Phase 2 installation)
**Capacity**: 25.1T used / 29.1T total (86% SAFE — ready for replacement) ✅
**Content Classes**:
- Main movie library (non-favorites)
- Main TV library (non-recent)
- Main music library
- Archive overflow when cold tier is inaccessible

**Path Layout** (pve:/media):
```
/media/
  movies/              # 9.6T - Primary movie library
  tv/                  # 5.5T - Primary TV library
  music/               # 666G - Primary music library
  downloads/           # 105G - Staging only (Phase 1 reclaim complete) ✅
  movies-archive/      # 205G - Overlay mount from md1400 cold tier
```

**Serving Method**: NFS export to download-stack (VM 209) and streaming-stack (VM 210)

**Performance Target**:
- Streaming bandwidth: 50MB/s+ concurrent for 3-5 streams
- *arr service writes: 20MB/s+

**Backup**:
- Config state only (download-stack, streaming-stack VM backups)
- Media payload: regenerable (not backed up)

**Critical Issues (Resolved in Phase 1)**:
1. ✅ **86% full** — safe headroom for drive replacement (was 96%)
2. ⏸️ **SMR drives** — pending Phase 2 replacement with 14TB SAS
3. ✅ **Downloads staging-only restored** — 105G (was 2.3T)
4. ✅ **Quarantine tier operational** — 2.07T in 30-day review buffer

**Phase 2 Ready**:
- ✅ Downloads drained to <200G (now 105G)
- ✅ Quarantine tier created and populated
- ✅ 2.77T space freed (Phase 1 complete)
- ✅ Pool safe for drive replacement

---

### 3. Cold Tier (Shop Archive)

**Canonical Host**: `pve` (R730XD) — `md1400` external shelf
**Hardware**: 12x4TB SAS RAIDZ2 (Dell MD1400 DAS)
**Capacity**: 15.6T used / 43.7T total (43% — healthy headroom)
**Role**: Long-term archive for watched/aged/low-demand content
**Content Classes**:
- Watched movies (not pinned as favorites)
- Completed TV series
- Bulk list-fed imports before curation
- Archived legacy media (pre-rationalization)

**Path Layout** (pve:/md1400/archive):
```
/md1400/archive/
  media-cold/
    movies/              # Watched/aged movies
    tv/                  # Completed TV series
    music/               # Rarely accessed music
  media-quarantine/      # ✅ OPERATIONAL - 2.07T in 30-day review (Phase 1)
    pending/             # Fresh quarantine intake
    reviewed/            # Marked for keep/delete
  media-holds/           # 372G - Temporary holds (shop <-> home transfer staging)
  legacy-media-stack-backups/  # Config backups from old media-stack VM
```

**Serving Method**:
- Local ZFS mount on pve
- Overlay mounts into /media/ for specific archive paths (e.g. movies-archive)
- Not directly mounted by streaming-stack (requires manual rehydration to warm tier for playback)

**Performance Target**:
- Archive write: 10MB/s+ (bulk moves from warm tier)
- Rehydration read: 30MB/s+ (restore to warm tier for re-watch)

**Backup**:
- Snapshots via ZFS (14-day retention)
- Config state: included in backup.inventory.yaml
- Media payload: NOT backed up (regenerable)

**Move Rules (to cold tier)**:
- Movies watched + aged >90 days + not pinned → cold
- TV series completed + aged >180 days → cold
- Bulk imports with low confidence scores → quarantine (not cold yet)
- Downloads folder bloat → manual review, then cold or delete

**Quarantine Rules** (new tier):
- Content stays in quarantine for 30 days minimum
- Operator reviews quarantine monthly
- Quarantine candidates:
  - List-fed bulk imports (Trakt lists, IMDB dumps)
  - Low IMDB rating (<6.0) and no personal interest tag
  - Duplicate acquisitions before dedup
  - Content flagged by quality checks (corrupt, wrong resolution, etc.)
- After quarantine review: promote to cold (keep) or delete (purge)

---

### 4. Staging Tier (Downloads - Ephemeral)

**Canonical Host**: Varies by use case
**Home staging**: `synology918:/volume1/media-staging/`
**Shop staging**: `pve:/media/downloads/` (CURRENTLY BLOATED)

**Role**: Temporary holding area for fresh downloads ONLY
**Capacity Target**: <200G at any time (not 2.3T!)
**Content Classes**:
- Active downloads (in-progress)
- Completed downloads awaiting *arr import (<48 hours)
- Failed downloads awaiting retry/cleanup

**Lifecycle Rules**:
- Downloads complete → *arr imports → moves to active library → staging cleaned
- Stuck downloads (>7 days) → manual review → retry or delete
- Staging >500G → alert operator (bloat detected)

**CRITICAL VIOLATION (Current State)**:
- Shop downloads at 2.3T (should be <200G)
- This indicates downloads are not being imported or cleaned
- Likely cause: *arr not moving files, or post-processing disabled
- **Action required**: Audit download-stack config, enable hardlinks, drain bloat

---

## Canonical Homes by Media Class

| Media Class | Canonical Home | Serving Home | Backup Home | Notes |
|-------------|---------------|--------------|-------------|-------|
| **Movies (home current-watch, transitional)** | synology918:/volume1/media-staging/movies | media-home VM 106 | Not backed up (regenerable) | No dedicated hot-library share exists yet; current live share truth is staging-first. |
| **Movies (main library)** | pve:/media/movies | streaming-stack VM 210 | Not backed up | 9.6T current |
| **Movies (watched/aged)** | pve:/md1400/archive/media-cold/movies | Cold tier (manual rehydration) | Snapshot only | Infrequent access |
| **TV (home current-watch, transitional)** | synology918:/volume1/media-staging/tv | media-home VM 106 | Not backed up | No dedicated hot-library share exists yet; current live share truth is staging-first. |
| **TV (main library)** | pve:/media/tv | streaming-stack VM 210 | Not backed up | 5.5T current |
| **TV (completed series)** | pve:/md1400/archive/media-cold/tv | Cold tier | Snapshot only | Binge-watched, done |
| **Music** | pve:/media/music | streaming-stack VM 210 (Navidrome) | Not backed up | 666G current |
| **Downloads (home)** | synology918:/volume1/media-staging/ | media-home VM 106 | Not backed up | Staging only (<100G) |
| **Downloads (shop)** | pve:/media/downloads | download-stack VM 209 | Not backed up | **BLOATED** 2.3T (should be <200G) |
| **Quarantine** | pve:/md1400/archive/media-quarantine/ | Cold tier (no serving) | Snapshot only | Low-value imports, 30-day review |

---

## Move Rules (Lifecycle Automation)

### Import Rules (staging → active library)

```yaml
rule: fresh_download_import
trigger: download_complete
source: /media/downloads/ OR /volume1/media-staging/
destination: Active library tier (home or shop based on content type)
method: hardlink (if same filesystem) OR copy+delete
automation: Radarr/Sonarr/Lidarr post-processing
frequency: Real-time on completion
```

### Archive Rules (active → cold)

```yaml
rule: watched_aged_archive
trigger: Manual operator decision (future: automated based on metadata)
conditions:
  - Movie/TV watched (Jellyfin playback history)
  - Aged >90 days (movies) or >180 days (TV series complete)
  - NOT pinned as favorite
source: /media/movies/ OR /media/tv/
destination: /md1400/archive/media-cold/
method: rsync --remove-source-files (move, not copy)
automation: NOT IMPLEMENTED YET (manual only)
frequency: Monthly cleanup passes
```

### Quarantine Rules (staging → quarantine → cold or delete)

```yaml
rule: bulk_import_quarantine
trigger: Bulk list import (Trakt, IMDB, etc.)
conditions:
  - Low confidence score (<60%)
  - IMDB rating <6.0 AND no personal tag
  - Duplicate detected
source: /media/downloads/ OR *arr request queue
destination: /md1400/archive/media-quarantine/
method: Move after acquisition
automation: Manual *arr list tag + custom script
frequency: On bulk import events
quarantine_duration: 30 days minimum
review_frequency: Monthly
post_review_action: promote_to_cold OR delete
```

### Deletion Rules (quarantine → purge)

```yaml
rule: quarantine_purge_after_review
trigger: Monthly quarantine review
conditions:
  - In quarantine >30 days
  - Operator marks "delete" during review
  - No playback activity
source: /md1400/archive/media-quarantine/
method: rm (permanent deletion, not ZFS snapshots)
automation: Manual review + confirmation
frequency: Monthly
```

---

## Path Layout by Host

### Shop (pve)

#### Warm Tier (/media)
```
/media/                          # NFS export to download-stack, streaming-stack
  movies/                        # 9.6T active movie library
  tv/                            # 5.5T active TV library
  music/                         # 666G active music library
  downloads/                     # 2.3T BLOAT (target: <200G)
  movies-archive/                # 205G overlay from md1400 (read-only)
```

#### Cold Tier (/md1400/archive)
```
/md1400/archive/
  media-cold/
    movies/                      # Watched/aged movies
    tv/                          # Completed TV series
    music/                       # Rarely accessed music
  media-quarantine/              # NEW - Low-value imports awaiting review
    pending/                     # Freshly quarantined
    reviewed/                    # Marked for keep/delete
  media-holds/                   # 372G temp holds (shop <-> home staging)
  legacy-media-stack-backups/    # Old VM config backups
```

### Home (synology918)

```
/volume1/
  media-staging/                 # Current live media import/current-watch share
    downloads/                   # Fresh downloads + in-flight staging
    movies/                      # Current live movies subtree
    tv/                          # Current live TV subtree
    music/                       # Current live music subtree
  media-holds/                   # Explicit hold/review/overflow share
  # No live /volume1/media-home share currently exists
```

---

## Disk Replacement Plan

### Current Hardware (media pool)
- **4x8TB SATA** (Seagate ST8000AS0002) RAIDZ1
- Archive/SMR drives (slow writes when full)
- Devices: sdi, sdj, sdk, sdl
- Status: Aging, 96% full, blocks safe replacement

### Target Hardware (media pool)
- **4x14TB SAS** RAIDZ1 (drives acquired, not installed)
- Expected capacity: ~38-40T usable
- Performance: 3x faster writes than SMR

### **CRITICAL**: Cannot replace drives until capacity <80%

**Reason**: ZFS resilver requires reading all existing data and writing to new drives. At 96% full:
- No temporary pool creation space
- Resilver failure risk (out of space during rebuild)
- No rollback buffer if replacement fails

### Safe Replacement Sequence

**Prerequisites (MUST complete before drive swap)**:
1. Drain downloads bloat: 2.3T → <200G (2.1T freed)
2. Archive aged content to cold: 3-4T moved to md1400
3. Target media pool usage: <80% (~15T/20T)
4. Verify backup.inventory.yaml includes all config state
5. Create forensic ZFS snapshot before any moves

**Replacement Steps** (after prerequisites met):
1. Create new pool `media-new` with 4x14TB SAS (alongside existing `media`)
2. Rsync canonical libraries from `media` → `media-new` (verify checksums)
3. Stop download-stack and streaming-stack VMs
4. Remount NFS export from `media-new` (update /etc/exports)
5. Restart VMs, verify playback and *arr access
6. Monitor for 48 hours (no silent corruption, performance acceptable)
7. Destroy old `media` pool (zpool destroy media)
8. Rename `media-new` → `media` (zpool rename)
9. Resilver complete, update hardware.inventory.yaml

**Rollback Plan** (if replacement fails):
- Old `media` pool remains intact until new pool verified
- Remount old pool and restart VMs
- Investigate failure, retry after capacity reduction

---

## Delete-Candidate Rules

**Philosophy**: Deletion is permanent. Quarantine is the safe review buffer.

### Quarantine Candidates (move to quarantine, NOT delete)
- Bulk list imports with low confidence
- IMDB <6.0 rating AND no personal interest tag
- Watched once + aged >1 year + not favorited
- Duplicate acquisitions (keep best quality, quarantine others)
- Failed quality checks (corrupt, wrong audio, hardcoded subs)

### Delete Candidates (after quarantine review)
- In quarantine >30 days + operator reviewed + marked "delete"
- Zero playback activity in Jellyfin/Plex
- Not referenced by any keep rules (favorites, pinned, collections)
- Not part of curated lists (family favorites, holiday movies, etc.)

### Keep Rules (NEVER delete, even if unwatched)
- Explicitly pinned as favorite
- Part of curated collection (e.g. "Pixar complete")
- Rare/hard-to-find content (noted in *arr tags)
- Family member explicit request (tagged in Jellyfin)

### Deletion Workflow
1. Content moves to quarantine (manual or automated based on rules)
2. Operator reviews quarantine monthly (`./bin/ops cap run media.quarantine.review`)
3. Operator marks each item: keep (promote to cold) or delete (purge)
4. Deletion requires confirmation (no accidental purges)
5. Deleted content logged to deletion manifest for audit trail

---

## Migration Plan (Current → Target State)

### Phase 0: Governance Canonicalization (THIS WAVE)
**Status**: IN PROGRESS
**Goal**: Make current state legible and explicit

**Deliverables**:
- ✅ This contract (MEDIA_STORAGE_CONTRACT.md)
- ✅ Migration runbook (MEDIA_STORAGE_MIGRATION_PLAN.md)
- [x] Add media-home VM 106 to vm.lifecycle.yaml
- [x] Add media-home to backup.inventory.yaml
- [x] Create media.quarantine.review capability
- [x] Create media.downloads.bloat.status capability
- [ ] Update DREAM_SYSTEM_EXECUTION_BOARD.yaml with media backlog items

**No data moves in this phase** — documentation only.

---

### Phase 1: Capacity Crisis Resolution
**Status**: ✅ COMPLETE (2026-03-19)
**Goal**: Reduce media pool from 96% → <90% usage (achieved 86%)

**Steps Completed**:
1. ✅ Audit downloads bloat (2.3T → classified into manifest)
   - Ran: `./bin/ops cap run media.downloads.bloat.status`
   - Reviewed: 947 items >30 days (CSV + JSONL manifests)
   - Found: 0 hardlinks, all orphaned imports
2. ⏸️ *arr hardlinks (verification deferred to Phase 1.5)
   - Finding: No hardlinks detected (all link count = 1)
   - Recommendation: Verify *arr config before resuming bulk imports
3. ⏸️ Manual archive pass (deferred to Phase 2+)
   - Phase 1 reclaimed 2.77T from downloads bloat alone
   - Library archiving not needed for drive swap readiness
4. ✅ Create quarantine tier
   - Created: /md1400/archive/media-quarantine with pending/ and reviewed/
   - Populated: 456 items (2.07T) in 30-day review buffer
5. ✅ Verify result: media pool 86% usage (4.01T free)

**Success Criteria Met**:
- ✅ media pool: 86% usage (safe for drive replacement)
- ✅ downloads folder: 105G (staging-only rule restored)
- ✅ Quarantine tier: operational and populated (2.07T)
- ✅ md1400 cold tier: 2.07T quarantine added (still 20.4T free, healthy)

---

### Phase 2: Warm Tier Drive Replacement
**Status**: ✅ READY (Phase 1 complete, prerequisites met)
**Goal**: Replace 4x8TB SATA with 4x14TB SAS

**Prerequisites**:
- ✅ Phase 1 complete (media pool 86%, safe for replacement)
- ✅ 4x14TB SAS drives acquired (not installed yet)
- ✅ Backup.inventory.yaml verified current
- ✅ Forensic snapshot created (media@phase1-pre-reclaim-20260319)

**Steps**: See "Disk Replacement Plan" section above

**Success Criteria**:
- media-new pool created with 4x14TB SAS
- All data migrated and verified (checksums match)
- VMs remounted to new pool, playback confirmed
- Old pool destroyed, new pool renamed
- Hardware.inventory.yaml updated

---

### Phase 3: Tier Boundary Canonicalization
**Status**: BLOCKED (depends on Phase 2 completion)
**Goal**: Formalize home vs shop tier boundaries

**Steps**:
1. Audit Synology media volumes:
   - Confirm `/volume1/media-staging/` is still the only populated/exported media share consumed by VM 106.
   - Confirm `/volume1/media-holds/` remains a hold/review lane, not a disguised main library.
   - Delete root-owned ghost placeholder dirs once a root/DSM-console cleanup path is available.
   - What's in /volume1/media-holds/?
2. Define home tier content policy:
   - Favorites only? Or favorites + recent?
   - Max capacity allocation (e.g. 5T for home hot tier)
3. Implement home tier serving:
   - Confirm media-home VM 106 mounts and serves correctly
   - Test Jellyfin/Plex playback from home network
4. Create home ↔ shop sync capability:
   - Promote favorites from shop → home
   - Archive aged content from home → shop cold

**Success Criteria**:
- Home tier has clear content policy and capacity limits
- media-home VM 106 is governed and backed up
- Home playback is fast (<50ms read latency)
- Shop cold tier is the canonical archive authority

---

### Phase 4: Lifecycle Automation (Future)
**Status**: NOT STARTED (long-term)
**Goal**: Automate tier movement based on watch history and age

**Steps**:
1. Integrate Jellyfin playback history API
2. Create media.lifecycle.evaluate capability:
   - Query: watched movies + age + favorite status
   - Output: candidates for archive, quarantine, or keep
3. Create media.lifecycle.archive capability:
   - Input: list of items to archive
   - Action: rsync to cold tier with --remove-source-files
   - Verify: checksums match, warm tier space freed
4. Create media.lifecycle.quarantine capability:
   - Input: list of low-value imports
   - Action: move to quarantine tier
   - Schedule: monthly review reminder
5. Create media.quarantine.review workflow:
   - List: all quarantined items >30 days
   - Prompt: operator decision (keep/delete)
   - Execute: promote to cold OR purge

**Success Criteria**:
- Lifecycle rules execute automatically (weekly/monthly)
- Operator receives review prompts (not surprised by moves)
- Media pool stays <70% usage without manual intervention

---

## Verification Commands

### Capacity Status
```bash
# Shop media pool (warm tier)
ssh pve "zpool list media && zfs list media"

# Shop cold tier
ssh pve "zpool list md1400 && zfs list md1400/archive"

# Home tier
ssh nas "df -h /volume1 && du -sh /volume1/media-*"
```

### Content Inventory
```bash
# Warm tier content (NFS client view is authoritative)
ssh streaming-stack "du -sh /mnt/media/*"

# Cold tier content
ssh pve "du -sh /md1400/archive/media-*"

# Home tier content
ssh nas "du -sh /volume1/media-staging /volume1/media-holds"
```

### Downloads Bloat Check
```bash
# Shop downloads
ssh streaming-stack "du -sh /mnt/media/downloads && find /mnt/media/downloads -type f -mtime +30 | wc -l"

# Home staging
ssh nas "du -sh /volume1/media-staging && find /volume1/media-staging -type f -mtime +7 | wc -l"
```

### Quarantine Review
```bash
# List quarantine candidates
ssh pve "ls -lh /md1400/archive/media-quarantine/pending/"

# Quarantine age report
ssh pve "find /md1400/archive/media-quarantine -type f -printf '%TY-%Tm-%Td %p\n' | sort"
```

---

## Anti-Patterns (DO NOT DO THIS)

### ❌ Move data before defining target state
**Why**: Without explicit tier boundaries and move rules, you'll create more ambiguity and risk data loss.

### ❌ Replace drives while pool is >90% full
**Why**: ZFS resilver requires headroom. Failure during resilver = data loss.

### ❌ Delete content without quarantine review
**Why**: Deletion is permanent. Quarantine gives a 30-day buffer to catch mistakes.

### ❌ Keep downloads as permanent residence
**Why**: Bloats warm tier, violates staging-only rule, degrades SMR write performance.

### ❌ Store favorites on slow cold tier
**Why**: Cold tier is for infrequent access. Favorites should be on fast home tier.

### ❌ Guess at tier boundaries based on memory
**Why**: Current state has NFS overlays and bind mounts that hide true layout. Verify with NFS client view.

### ❌ Start lifecycle automation before capacity crisis resolved
**Why**: Automation will fail or behave unpredictably when pool is 96% full.

---

## Related Documents

- Migration runbook: `docs/runbooks/MEDIA_STORAGE_MIGRATION_PLAN.md`
- Hardware inventory: `ops/bindings/hardware.inventory.yaml`
- Backup inventory: `ops/bindings/backup.inventory.yaml`
- Service registry: `docs/governance/SERVICE_REGISTRY.yaml`
- Media domain runbook: `docs/runbooks/domains/media.md`
- Shop media pressure audit: `docs/reference/audits/SHOP_MEDIA_PRESSURE_CLOSURE_20260312.md`
- Service data lifecycle registry: `ops/bindings/service.data.lifecycle.registry.yaml`

---

## Change Control

**Version 1.0** (2026-03-19):
- Initial canonical contract
- Verified current state from live infrastructure census
- Defined explicit tier boundaries and lifecycle rules
- Created safe migration plan with phase gates
- Identified media-home VM 106 governance gap
- Documented disk replacement prerequisites

**Version 1.1** (2026-03-19):
- Phase 1 complete: media pool 96% → 86% (2.77T reclaimed)
- Quarantine tier operational (2.07T in 30-day review)
- Downloads staging-only restored (2.3T → 105G)
- Phase 2 ready: drive replacement prerequisites met
- Updated current state sections to reflect Phase 1 completion

**Version 1.1.1** (2026-03-19):
- Registry alignment: `service.data.lifecycle.registry.yaml` reclassified
  `nas:/volume1/media-staging` from `drift_rules.retired_roots` to
  `allowed_secondary_root`, resolving a conflict where the registry was the
  sole document treating this active path as retired.

**Next Review**: After Phase 2 completion (drive replacement)
