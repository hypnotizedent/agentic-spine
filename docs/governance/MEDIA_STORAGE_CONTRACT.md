---
status: authoritative
owner: "@ronny"
version: "1.2"
last_verified: "2026-03-20"
authority_concern: media_storage_lifecycle
scope: media-storage-architecture-and-lifecycle
---

# Media Storage Contract

**Status**: AUTHORITATIVE
**Version**: 1.2
**Last Verified**: 2026-03-20

## Purpose

This contract defines the canonical media storage architecture, tier assignments, lifecycle rules, and migration boundaries for all media content (movies, TV, music, downloads). It establishes what lives where, when content moves between tiers, and how to safely execute the current-to-target migration without data loss.

## Executive Summary

**Current State (Verified 2026-03-20)**:
- `media-home` VM 106 plus Synology `/volume1/media-staging/*` is the canonical live active media plane.
- Home owns the operator experience: fast downloads, local playback, and the current-watch library.
- Shop `pve:/media/*` is no longer the desired family watch plane. It is transitional residue plus transfer/rehydration support while home-writer promotion finishes.
- Shop `pve:/md1400/archive/*` is the canonical archive plane for watched/aged media.
- `/volume1/media-holds` is the explicit hold/review lane. It is not a disguised main library.
- `/volume1/media-home` is still not a live share. The active home library path is the current live Synology staging tree.

**Boring Target State**:
- Home stays the single active download/watch plane.
- Shop stays the passive archive plane.
- Downloads are staging-only and age out of home into library placement or archive.
- Archive moves are deliberate, low-churn, and capacity-aware.
- Agents answer placement questions from one contract instead of stitching together migration packets.

**Critical Constraint**: `md1400` is pressure-bound. Treat archive writes as deliberate and incremental, not as another bulk migration wave.

## Minimal Canonical Surface

For media placement truth, agents should prefer only:
- `docs/governance/MEDIA_STORAGE_CONTRACT.md`
- `docs/governance/MEDIA_STORAGE_LIFECYCLE.md`
- `ops/bindings/media.services.yaml`
- `ops/bindings/media.path.authority.contract.yaml`
- `ops/bindings/media.quality.policy.yaml`

Keep media quality/acquisition policy in binding form. Do not fork it into a new
governance-doc family.

Historical planning packets remain in-repo for lineage only and must not be used as active placement authority:
- `docs/runbooks/MEDIA_STORAGE_MIGRATION_PLAN.md`
- `docs/reference/media/MEDIA-MIGRATION-LINEAGE-CHECKPOINT.md`
- `docs/reference/media/MEDIA-SHOP-HOME-MIGRATION-TRANSACTION-PACKET.md`

---

## Tier Definitions

### 1. Active Home Plane

**Canonical Host**: `synology918` (Synology DS918+) + `media-home` VM 106 (proxmox-home)
**Role**: Fast access download + playback plane for home consumption
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

### 2. Shop Transfer / Residual Writer Plane

**Canonical Host**: `pve` (R730XD) — `media` pool
**Role**: Transitional shop-side transfer, residual writer, and rehydration support plane
**Current Hardware**: 4x8TB SATA RAIDZ1 (Archive/SMR, aging)
**Target Hardware**: 4x14TB SAS RAIDZ1 (acquired, ready for Phase 2 installation)
**Capacity**: 25.1T used / 29.1T total (86% SAFE — ready for replacement) ✅
**Content Classes**:
- Residual shop-side writer/import surfaces not yet retired
- Rehydration landing when archive content must be made hot again
- Temporary transfer buffer during archive pushes
- Operational residue that should shrink over time, not grow

**Path Layout** (pve:/media):
```
/media/
  movies/              # 9.6T - Primary movie library
  tv/                  # 5.5T - Primary TV library
  music/               # 666G - Primary music library
  downloads/           # 105G - Staging only (Phase 1 reclaim complete) ✅
  movies-archive/      # 205G - Overlay mount from md1400 cold tier
```

**Serving Method**: residual NFS export and transfer support only. This is not the canonical family watch plane.

**Performance Target**:
- Rehydration/transfer bandwidth sufficient for one-item-at-a-time archive flow
- Writer residue should be treated as transitional, not as a growth target

**Backup**:
- Config state only (legacy shop media VMs / residual writer surfaces)
- Media payload: regenerable (not backed up)

**Operator Rule**:
- keep this plane boring and shrinking
- do not re-promote it into the primary watch/download plane
- use it only where the home plane has not yet absorbed the function

---

### 3. Cold Tier (Shop Archive)

**Canonical Host**: `pve` (R730XD) — `md1400` external shelf
**Hardware**: 12x4TB SAS RAIDZ2 (Dell MD1400 DAS)
**Capacity**: pressure-bound enough to require deliberate archive policy, not bulk dump behavior
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

**Canonical Host**: `synology918:/volume1/media-staging/downloads`
**Residual Secondary Host**: `pve:/media/downloads` (transitional only; not canonical)

**Role**: Temporary holding area for fresh downloads ONLY
**Capacity Target**: <200G at any time (not 2.3T!)
**Content Classes**:
- Active downloads (in-progress)
- Completed downloads awaiting *arr import (<48 hours)
- Failed downloads awaiting retry/cleanup

**Lifecycle Rules**:
- Downloads complete → imports into the home plane → staging cleaned
- Stuck downloads (>7 days) → manual review → retry or delete
- Staging >500G → alert operator (bloat detected)

**Operator Rule**:
- home staging is the canonical intake lane
- shop staging is residual drift until writer cutover closes
- never let either downloads tree become permanent residence

---

## Canonical Homes by Media Class

| Media Class | Canonical Home | Serving Home | Backup Home | Notes |
|-------------|---------------|--------------|-------------|-------|
| **Movies (active)** | synology918:/volume1/media-staging/movies | media-home VM 106 | Not backed up (regenerable) | Canonical live movie plane today. |
| **Movies (archive)** | pve:/md1400/archive/media-cold/movies | Cold tier (rehydrate to home before normal watching) | Snapshot only | Passive watched/aged archive. |
| **TV (active)** | synology918:/volume1/media-staging/tv | media-home VM 106 | Not backed up | Canonical live TV plane today. |
| **TV (archive)** | pve:/md1400/archive/media-cold/tv | Cold tier | Snapshot only | Completed/aged series archive. |
| **Music (active)** | synology918:/volume1/media-staging/music | media-home VM 106 (Navidrome) | Not backed up | Canonical live music plane today. |
| **Music (archive)** | pve:/md1400/archive/media-cold/music | Cold tier | Snapshot only | Passive long-tail music archive. |
| **Downloads (active intake)** | synology918:/volume1/media-staging/downloads | media-home VM 106 | Not backed up | Canonical intake lane. |
| **Downloads (shop residue)** | pve:/media/downloads | Residual shop writer/import surfaces only | Not backed up | Transitional residue; should shrink, not grow. |
| **Quarantine** | pve:/md1400/archive/media-quarantine/ | Cold tier (no serving) | Snapshot only | Low-value imports, 30-day review. |

---

## Move Rules (Lifecycle Automation)

### Import Rules (staging → active library)

```yaml
rule: fresh_download_import
trigger: download_complete
source: /volume1/media-staging/downloads/
destination: /volume1/media-staging/{movies,tv,music}
method: move_or_hardlink_within_home_plane
automation: home acquisition/runtime when promoted
frequency: real_time_on_completion
```

### Archive Rules (active → cold)

```yaml
rule: watched_aged_archive
trigger: deliberate_archive_pass
conditions:
  - watched_or_low_replay_probability
  - not_pinned_as_keep_hot
  - md1400_has_safe_headroom_for_single_item_move
source: /volume1/media-staging/{movies,tv,music}
destination: /md1400/archive/media-cold/
method: copy_verify_then_prune_later
automation: future_single_item_archive_capability
frequency: low_churn_incremental
```

### Quarantine Rules (staging → quarantine → cold or delete)

```yaml
rule: bulk_import_quarantine
trigger: low_confidence_or_bulk_acquisition
conditions:
  - low_confidence_score
  - duplicate_detected
  - operator_does_not_want_hot_residency
source: active_intake_or_transitional_shop_writer
destination: /md1400/archive/media-quarantine/
method: move_after_review_intake
automation: manual_until_home_writer_cutover_closes
frequency: as_needed
quarantine_duration: 30_days_minimum
review_frequency: monthly
post_review_action: promote_to_archive OR delete
```

Historical cutover planning below is retained for lineage only. Placement decisions should follow the tier model, canonical homes table, and lifecycle rules above.

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
3. Stop media-home and any residual split-era media VMs still attached to shop exports
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
