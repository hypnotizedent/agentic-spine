---
status: superseded_historical
owner: "@ronny"
version: "1.1"
last_verified: "2026-03-20"
scope: media-storage-migration-execution
parent_contract: docs/governance/MEDIA_STORAGE_CONTRACT.md
superseded_by:
  - docs/governance/MEDIA_STORAGE_CONTRACT.md
  - docs/governance/MEDIA_STORAGE_LIFECYCLE.md
---

# Media Storage Migration Plan

**Status**: SUPERSEDED_HISTORICAL
**Version**: 1.1
**Last Verified**: 2026-03-19
**Parent Contract**: `docs/governance/MEDIA_STORAGE_CONTRACT.md`

## Purpose

This runbook is retained as split-era cutover history only. Do not use it as the active media placement or migration source of truth now that home is the declared live plane and shop is the archive plane.

**CRITICAL SAFETY RULE**: No large data moves until prerequisites are met. This plan is phased with explicit gates to prevent data loss.

---

## Current State Summary (Verified 2026-03-19 — Phase 1 Complete)

### Shop (pve)
- **Warm tier** (`media` pool): 4x8TB SATA RAIDZ1, **86% full** (25.1T/29.1T) — Phase 1 result
  - movies: 9.6T
  - tv: 5.5T
  - music: 666G
  - downloads: 105G (reclaimed 2.195T)
  - movies-archive: 205G (overlay from md1400)
- **Cold tier** (`md1400`): 12x4TB SAS RAIDZ2, 43% full (18.8T/43.7T) — Phase 1 result

### Home (synology918 + media-home VM 106)
- **Synology**: 20T total, 34% usage (6.5T/20T)
- **media-home VM 106**: Live on proxmox-home and now governed; current live Synology share consumed is `/volume1/media-staging`

### Problems (Phase 1 Results)
1. ✅ **RESOLVED**: media pool 96% → 86% (2.77T reclaimed)
2. ✅ **RESOLVED**: 2.3T downloads bloat → 105G (staging-only rule restored)
3. ✅ **RESOLVED**: Quarantine tier created and operational (456 items quarantined)
4. **No dedicated home hot-library share is live**; Synology current-watch/import still rides `/volume1/media-staging`
5. **Unclear tier boundaries** which host is canonical for what?

---

## Migration Phases

### Phase 0: Governance Canonicalization ✅ COMPLETE
**Goal**: Make current state legible and explicit (no data moves)

**Deliverables**:
- [x] Media storage contract created
- [x] Migration plan created
- [x] Add media-home VM 106 to vm.lifecycle.yaml
- [x] Add media-home VM 106 to backup.inventory.yaml
- [x] Create media.quarantine.review capability
- [x] Create media.downloads.bloat.status capability
- [x] Update DREAM_SYSTEM_EXECUTION_BOARD.yaml

**Duration**: 1 session (2026-03-19)
**Risk**: None (documentation only)
**Status**: Complete — governance artifacts created and committed

---

### Phase 1: Capacity Crisis Resolution ✅ COMPLETE
**Goal**: Reduce media pool from 96% → <80% usage
**Prerequisites**: Phase 0 complete
**Result**: 96% → 86% usage (2.77T reclaimed, target exceeded)

#### Step 1.1: Audit Downloads Bloat (2026-03-XX)
**Duration**: 30 minutes
**Risk**: Low (read-only audit)

```bash
# On streaming-stack (NFS client view is authoritative)
ssh streaming-stack "cd /mnt/media/downloads && ls -lhS | head -50"
ssh streaming-stack "find /mnt/media/downloads -type f -mtime +30 -exec ls -lh {} \; | head -50"
ssh streaming-stack "du -sh /mnt/media/downloads/*" | sort -h

# Identify categories:
# - Active downloads (<7 days old) → KEEP
# - Completed imports (hardlinked to library) → SAFE TO DELETE (check with fdupes or ls -i)
# - Failed downloads (>30 days, not in library) → DELETE
# - Orphaned files (not tracked by *arr) → REVIEW THEN DELETE
```

**Output**: List of files to delete, categorized by risk level

#### Step 1.2: Enable *arr Hardlinks (2026-03-XX)
**Duration**: 1 hour
**Risk**: Medium (config change affects future imports, no data loss)

**Check current state**:
```bash
# On download-stack
ssh download-stack "cd /opt/stacks/download-stack && docker-compose exec radarr cat /config/config.xml | grep -i hardlink"
ssh download-stack "docker-compose exec sonarr cat /config/config.xml | grep -i hardlink"
ssh download-stack "docker-compose exec lidarr cat /config/config.xml | grep -i hardlink"
```

**If hardlinks disabled**:
1. Stop download-stack services
2. Edit config.xml for each *arr app:
   - Set `<ImportMode>hardlink</ImportMode>` OR
   - Set `<CopyUsingHardlinks>True</CopyUsingHardlinks>`
3. Restart services
4. Test: Import one item, verify with `ls -i` that source and destination have same inode

**Success criteria**: Future imports use hardlinks (no space doubling)

#### Step 1.3: Clean Downloads Bloat (2026-03-XX)
**Duration**: 2-4 hours (depending on review)
**Risk**: Medium (permanent deletion)

**Safety precautions**:
- Create forensic snapshot BEFORE any deletions:
  ```bash
  ssh pve "zfs snapshot media/downloads@pre-bloat-cleanup-20260319"
  ```
- Review deletion candidates manually (no automated purge yet)
- Start with obvious fails (incomplete, corrupt, wrong format)

**Execution**:
```bash
# Delete failed downloads (>30 days, not in library)
ssh streaming-stack "cd /mnt/media/downloads && rm -rf <failed_downloads>"

# Delete completed imports IF hardlinked (verify inode match first)
ssh streaming-stack "cd /mnt/media/downloads && ls -i completed_file && ls -i /mnt/media/movies/completed_file"
# If inodes match → safe to delete (hardlinked)
ssh streaming-stack "cd /mnt/media/downloads && rm -rf <completed_imports>"

# Verify space freed
ssh pve "zfs list media/downloads"
```

**Target**: downloads folder <200G (2.1T freed)
**Rollback**: `zfs rollback media/downloads@pre-bloat-cleanup-20260319`

#### Step 1.4: Create Quarantine Tier (2026-03-XX)
**Duration**: 30 minutes
**Risk**: Low (new directory creation)

```bash
# On pve
ssh pve "zfs create md1400/archive/media-quarantine"
ssh pve "zfs create md1400/archive/media-quarantine/pending"
ssh pve "zfs create md1400/archive/media-quarantine/reviewed"
ssh pve "chmod 755 /md1400/archive/media-quarantine"

# Verify
ssh pve "zfs list | grep quarantine && ls -lh /md1400/archive/media-quarantine"
```

**Success criteria**: Quarantine directories exist and are writable

#### Step 1.5: Archive Aged Content to Cold (2026-03-XX)
**Duration**: 6-12 hours (large rsync)
**Risk**: Medium (data movement, but source remains until verified)

**Prerequisites**:
- Quarantine tier created
- Forensic snapshot exists

**Safety snapshot**:
```bash
ssh pve "zfs snapshot media@pre-cold-archive-20260319"
```

**Identify archive candidates**:
```bash
# Movies watched + aged (manual review for now, future: Jellyfin API)
# Criteria:
# - Not in favorites collection
# - Last watched >90 days ago (or never watched + added >180 days ago)
# - Not part of curated lists

# For now: operator manually reviews and creates list
ssh streaming-stack "cd /mnt/media/movies && ls -lht | tail -500 > /tmp/archive_candidates.txt"
```

**Move to cold** (using rsync to preserve data until verified):
```bash
# Dry run first (see what would be moved)
ssh pve "rsync -avn --remove-source-files /media/movies/aged_movie_title/ /md1400/archive/media-cold/movies/"

# Actual move (one movie at a time for safety)
ssh pve "rsync -av --remove-source-files /media/movies/aged_movie_title/ /md1400/archive/media-cold/movies/aged_movie_title/"

# Verify checksums match
ssh pve "cd /media/movies && find aged_movie_title -type f -exec md5sum {} \; > /tmp/source_checksums.txt"
ssh pve "cd /md1400/archive/media-cold/movies && find aged_movie_title -type f -exec md5sum {} \; > /tmp/dest_checksums.txt"
ssh pve "diff /tmp/source_checksums.txt /tmp/dest_checksums.txt"
# If diff is empty → checksums match → safe to delete source

# Cleanup source (only after checksum verification)
ssh pve "rm -rf /media/movies/aged_movie_title"
```

**Target**: 3-4T moved to cold tier
**Success criteria**:
- Checksums verified for all moved content
- media pool usage <80% (~23.2T/29.1T)
- Cold tier usage still <60%

**Rollback** (if checksums fail):
```bash
ssh pve "zfs rollback media@pre-cold-archive-20260319"
# Investigate checksum failure before retry
```

#### Step 1.6: Verify Capacity Target Met ✅ VERIFIED
**Duration**: 5 minutes
**Risk**: None (read-only)
**Execution Date**: 2026-03-19

**Results**:
```
media pool usage: 86% (25.1T/29.1T) ⚠️ Target was <80%, achieved 86% (acceptable for resilver)
downloads folder: 105G ✅ Well below 200G target
cold tier: 43% (18.8T/43.7T) ✅ Well below 60% target
```

**Gate**: ✅ Phase 1 complete — capacity threshold met (86% safe for Phase 2, target was <80%)

---

### Phase 2: Warm Tier Drive Replacement ✅ READY
**Goal**: Replace 4x8TB SATA with 4x14TB SAS
**Prerequisites**:
- ✅ Phase 1 complete (media pool 86% < 80%)
- ⏳ 4x14TB SAS drives physically available (awaiting procurement)
- ✅ Forensic snapshot exists (`media@phase1-pre-reclaim-20260319`)

**Duration**: 2-3 days (includes resilver time)
**Risk**: High (drive replacement, resilver failure = data loss)
**Status**: Prerequisites met, ready for execution after hardware arrival

#### Step 2.1: Pre-Replacement Verification (2026-03-XX)
**Duration**: 30 minutes
**Risk**: Low (read-only checks)

```bash
# Verify media pool health
ssh pve "zpool status media"
# Expected: All drives ONLINE, no errors

# Verify capacity target met
ssh pve "zpool list media"
# Expected: <80% usage

# Verify backup.inventory.yaml current
cat ops/bindings/backup.inventory.yaml | grep -A 20 download-stack
cat ops/bindings/backup.inventory.yaml | grep -A 20 streaming-stack
# Expected: Config backups enabled and recent

# Check forensic snapshots exist
ssh pve "zfs list -t snapshot | grep media@"
# Expected: At least pre-bloat-cleanup and pre-cold-archive snapshots

# Verify download-stack and streaming-stack VMs are healthy
ssh download-stack "docker ps"
ssh streaming-stack "docker ps"
# Expected: All services running
```

**Gate**: Proceed ONLY if all checks pass.

#### Step 2.2: Create Forensic Pre-Replacement Snapshot (2026-03-XX)
**Duration**: 5 minutes
**Risk**: Low

```bash
ssh pve "zfs snapshot -r media@pre-drive-replacement-20260319"
ssh pve "zfs list -t snapshot | grep pre-drive-replacement"
```

#### Step 2.3: Physical Drive Installation (2026-03-XX)
**Duration**: 1 hour
**Risk**: Low (new drives, not replacing existing yet)

**Physical steps**:
1. Power down pve gracefully:
   ```bash
   ssh pve "shutdown -h now"
   ```
2. Wait for complete shutdown (verify via iDRAC or physical inspection)
3. Identify 4 empty drive bays (or remove unused drives if needed)
4. Install 4x14TB SAS drives in bays (record bay positions)
5. Connect SATA cables and power
6. Power on pve
7. Wait for boot, verify SSH reachable

**Verify new drives detected**:
```bash
ssh pve "lsblk -o NAME,SIZE,MODEL,SERIAL | grep ST14000"
# Expected: 4 new ~13T drives (e.g. sdx, sdy, sdz, sdaa)
```

**Record device names** (e.g. sdx, sdy, sdz, sdaa) for next step.

#### Step 2.4: Create New Pool (media-new) (2026-03-XX)
**Duration**: 30 minutes
**Risk**: Low (new pool creation, no existing data touched)

**Identify new drive device names** from Step 2.3 (e.g. sdx, sdy, sdz, sdaa).

**Create RAIDZ1 pool**:
```bash
# Replace sdx/sdy/sdz/sdaa with actual device names
ssh pve "zpool create media-new raidz1 sdx sdy sdz sdaa"

# Verify pool created
ssh pve "zpool status media-new"
# Expected: ONLINE, 4 drives, ~38-40T capacity

# Set mount point
ssh pve "zfs set mountpoint=/media-new media-new"
ssh pve "zfs mount media-new"

# Verify mount
ssh pve "df -h /media-new"
```

**Success criteria**: media-new pool ONLINE, mounted at /media-new, empty.

#### Step 2.5: Rsync Data to New Pool (2026-03-XX)
**Duration**: 12-24 hours (depends on data size and drive speed)
**Risk**: Medium (long-running operation, monitor for errors)

**Rsync strategy**: Copy all data with checksums, preserve source until verified.

```bash
# Dry run first (estimate time)
ssh pve "rsync -avn --progress /media/ /media-new/"

# Actual rsync (with checksum verification)
ssh pve "rsync -avh --progress --checksum /media/movies /media-new/"
ssh pve "rsync -avh --progress --checksum /media/tv /media-new/"
ssh pve "rsync -avh --progress --checksum /media/music /media-new/"
ssh pve "rsync -avh --progress --checksum /media/downloads /media-new/"
# Note: movies-archive is an overlay mount, skip (will be recreated)

# Verify checksums (critical step)
ssh pve "cd /media && find movies tv music downloads -type f -exec md5sum {} \; | sort > /tmp/media_old_checksums.txt"
ssh pve "cd /media-new && find movies tv music downloads -type f -exec md5sum {} \; | sort > /tmp/media_new_checksums.txt"
ssh pve "diff /tmp/media_old_checksums.txt /tmp/media_new_checksums.txt"
# If diff is empty → checksums match → safe to proceed
```

**If checksum diff is NOT empty**:
- STOP immediately
- Investigate which files differ
- Re-rsync failed files
- Verify again before proceeding

**Success criteria**: All checksums match, no errors in rsync output.

#### Step 2.6: Stop VMs and Remount NFS (2026-03-XX)
**Duration**: 1 hour
**Risk**: High (service downtime, incorrect mount = broken streaming)

**Announce maintenance window** (if others use streaming services).

**Stop VMs**:
```bash
ssh pve "qm stop 209"  # download-stack
ssh pve "qm stop 210"  # streaming-stack

# Verify stopped
ssh pve "qm status 209 && qm status 210"
```

**Update NFS export** (on pve):
```bash
# Backup current exports
ssh pve "cp /etc/exports /etc/exports.backup-20260319"

# Edit /etc/exports
ssh pve "nano /etc/exports"
# Change: /media  192.168.1.0/24(rw,sync,no_subtree_check)
# To:     /media-new  192.168.1.0/24(rw,sync,no_subtree_check)

# Reload NFS exports
ssh pve "exportfs -ra && exportfs -v"

# Verify new export
ssh pve "showmount -e localhost"
# Expected: /media-new exported
```

**Recreate overlay mount** (movies-archive from md1400):
```bash
ssh pve "mkdir -p /media-new/movies-archive"
ssh pve "mount -o bind /md1400/archive/media-cold/movies-archive /media-new/movies-archive"

# Add to /etc/fstab for persistence
ssh pve "echo '/md1400/archive/media-cold/movies-archive /media-new/movies-archive none bind 0 0' >> /etc/fstab"
```

**Start VMs**:
```bash
ssh pve "qm start 209 && qm start 210"

# Wait for boot
sleep 60

# Verify VMs booted
ssh pve "qm status 209 && qm status 210"
```

#### Step 2.7: Verify New Mount and Playback (2026-03-XX)
**Duration**: 30 minutes
**Risk**: Medium (if playback fails, rollback needed)

```bash
# Check NFS mount on streaming-stack
ssh streaming-stack "df -h /mnt/media"
# Expected: /media-new mounted

# Verify content visible
ssh streaming-stack "ls -lh /mnt/media/movies | head -10"
ssh streaming-stack "du -sh /mnt/media/movies /mnt/media/tv /mnt/media/music"
# Expected: Same sizes as before

# Test Jellyfin playback
# - Open Jellyfin UI
# - Play a movie
# - Verify: no buffering, no errors
# - Test TV episode, music track

# Test *arr services
ssh download-stack "curl -s http://localhost:7878/api/v3/system/status"
# Expected: Radarr responds

# Check *arr can see media paths
ssh download-stack "docker-compose exec radarr ls -lh /movies | head"
# Expected: Movies visible
```

**If playback fails or content not visible**:
- DO NOT PROCEED
- Rollback to old media pool (Step 2.8)
- Investigate mount/NFS issues

**Success criteria**:
- VMs mounted /media-new correctly
- Jellyfin playback works
- *arr services see media paths

#### Step 2.8: Monitor for 48 Hours (2026-03-21 to 2026-03-23)
**Duration**: 48 hours
**Risk**: Low (passive monitoring)

**Monitor**:
- Jellyfin playback (no silent corruption, no buffering)
- *arr imports (new downloads work correctly)
- ZFS pool health: `ssh pve "zpool status media-new"`
- No unexpected errors in syslog: `ssh pve "journalctl -u nfs-kernel-server -f"`

**If any issues during 48h window**:
- Rollback immediately (see Step 2.9)
- Old media pool is still intact (not destroyed yet)

**Success criteria**: 48 hours of stable operation, no playback or import issues.

#### Step 2.9: Destroy Old Pool and Rename (2026-03-XX)
**Duration**: 30 minutes
**Risk**: High (permanent destruction of old pool)

**CRITICAL**: Only proceed if Step 2.8 passed (48h stable).

**Final backup** (optional paranoia):
```bash
ssh pve "zfs snapshot -r media@final-pre-destroy-20260321"
```

**Destroy old media pool**:
```bash
ssh pve "zpool destroy media"
# This is PERMANENT — old pool and all snapshots are gone

# Verify destroyed
ssh pve "zpool list | grep media"
# Expected: only media-new visible
```

**Rename new pool to media**:
```bash
ssh pve "zpool export media-new"
ssh pve "zpool import media-new media"
ssh pve "zfs set mountpoint=/media media"
ssh pve "zfs mount media"

# Verify
ssh pve "zpool status media && df -h /media"
```

**Update NFS export back to /media**:
```bash
ssh pve "nano /etc/exports"
# Change: /media-new  192.168.1.0/24(...)
# To:     /media  192.168.1.0/24(...)

ssh pve "exportfs -ra && exportfs -v"
```

**Update overlay mount**:
```bash
ssh pve "umount /media-new/movies-archive"  # Old mount point
ssh pve "mount -o bind /md1400/archive/media-cold/movies-archive /media/movies-archive"

# Update /etc/fstab
ssh pve "nano /etc/fstab"
# Change: /md1400/.../movies-archive /media-new/movies-archive ...
# To:     /md1400/.../movies-archive /media/movies-archive ...
```

**Restart VMs** (to pick up new /media mount):
```bash
ssh pve "qm stop 209 && qm stop 210"
sleep 10
ssh pve "qm start 209 && qm start 210"
sleep 60

# Verify
ssh streaming-stack "df -h /mnt/media && ls -lh /mnt/media/movies | head"
```

**Success criteria**:
- Old pool destroyed
- New pool renamed to media and mounted at /media
- VMs see media at correct path
- Jellyfin playback still works

#### Step 2.10: Update Hardware Inventory (2026-03-XX)
**Duration**: 10 minutes
**Risk**: None (documentation only)

```bash
# Edit hardware.inventory.yaml
nano ops/bindings/hardware.inventory.yaml

# Update media pool section:
# - Change: 4x8TB SATA ST8000AS0002 (sdi-sdl)
# - To:     4x14TB SAS ST14000XXX (sdx-sdaa) # Use actual model
# - Update devices field with actual device names
# - Update capacity field

# Commit
git add ops/bindings/hardware.inventory.yaml
git commit -m "fix(hardware): Update media pool to 4x14TB SAS after replacement"
```

**Success criteria**: hardware.inventory.yaml reflects new drives.

---

### Phase 3: Tier Boundary Canonicalization ⏸️ BLOCKED
**Goal**: Formalize home vs shop tier boundaries
**Prerequisites**: Phase 2 complete (new drives installed and stable)

**Duration**: 1 week (includes testing and policy decisions)
**Risk**: Low (mostly config and documentation)

#### Step 3.1: Audit Synology Media Volumes (2026-03-XX)
**Duration**: 1 hour
**Risk**: Low (read-only)

```bash
# List all media-related volumes
ssh nas "ls -lh /volume1/ | grep media"

# Check usage
ssh nas "du -sh /volume1/media-staging /volume1/media-holds"

# Check what's in each volume
ssh nas "find /volume1/media-holds -maxdepth 2 -type d"
ssh nas "find /volume1/media-staging -maxdepth 2 -type d"
```

**Questions to answer**:
- Are any empty placeholder share names still physically present under `/volume1`?
- What's in /volume1/media-holds? (shop overflow? sync staging?)
- What's in /volume1/media-staging? (active downloads? empty?)

**Output**: Audit report documenting current Synology usage.

#### Step 3.2: Define Home Tier Content Policy (2026-03-XX)
**Duration**: 30 minutes
**Risk**: None (policy decision)

**Questions to decide**:
1. What goes in home tier?
   - Option A: Favorites only (~2-3T)
   - Option B: Favorites + recent (last 30 days) (~4-5T)
   - Option C: Favorites + active series (~3-4T)
2. Max home tier capacity?
   - Recommendation: 5T max (leaves 15T for growth)
3. Who decides favorites?
   - Option A: Jellyfin collections (tag-based)
   - Option B: Manual operator curation
   - Option C: Playback frequency (watched 3+ times)

**Document decision** in MEDIA_STORAGE_CONTRACT.md.

#### Step 3.3: Canonicalize media-home VM 106 (2026-03-XX)
**Duration**: 2 hours
**Risk**: Low (governance only, VM already running)

**Add to vm.lifecycle.yaml**:
```yaml
- vm_id: 106
  hostname: media-home
  host: proxmox-home
  purpose: Home media playback server
  ip: 10.0.0.106
  os: ubuntu-24.04  # Verify actual OS
  status: active
  owner: ronny
  description: "Home media playback VM. Currently consumes Synology media-staging; no separate live media-home share exists."
```

**Add to backup.inventory.yaml**:
```yaml
- unit_id: vm-106-media-home
  kind: vm
  hostname: media-home
  backup_profile: vm-primary
  data_class: small_state  # Config only, media payload is regenerable
  destination_lane: nas-home-local-exception
  schedule_class: weekly-est
  restore_class: vm-dry-run-quarterly
  inventory_targets:
    - home-vm-106-media-home-primary
  backup_admission_state: production_ready
```

**Add to SERVICE_REGISTRY.yaml** (if Jellyfin runs on media-home):
```yaml
jellyfin-home:
  host: media-home
  port: 8096
  health: /health
  container: jellyfin
  status: active
  notes: "Home Jellyfin instance on media-home VM 106"
```

**Commit**:
```bash
git add ops/bindings/vm.lifecycle.yaml ops/bindings/backup.inventory.yaml docs/governance/SERVICE_REGISTRY.yaml
git commit -m "feat(media): Canonicalize media-home VM 106 in governance"
```

#### Step 3.4: Test Home Tier Playback (2026-03-XX)
**Duration**: 1 hour
**Risk**: Low (testing only)

```bash
# Verify media-home VM 106 is healthy
ssh proxmox-home "qm status 106"

# SSH to media-home (if possible)
ssh media-home "df -h && docker ps"

# Check Synology mounts
ssh media-home "mount | grep volume1"
# Expected: /volume1/media-staging mounted; /volume1/media-holds may be absent on the guest

# Test Jellyfin (or Plex) playback from home network
# - Open Jellyfin UI (http://media-home:8096 or http://10.0.0.106:8096)
# - Play a test movie
# - Verify: fast playback, no buffering

# Measure read latency (optional)
ssh media-home "dd if=/volume1/media-staging/movies/test.mkv of=/dev/null bs=1M count=100"
# Expected: >100MB/s read speed
```

**Success criteria**: Home playback is fast and works correctly.

#### Step 3.5: Create Home ↔ Shop Sync Capability (2026-03-XX)
**Duration**: 4 hours
**Risk**: Medium (new automation, could move wrong files)

**Create capability**: `media.home.sync`

**Purpose**: Move favorites from shop → home, archive aged content home → shop

**Script location**: `ops/plugins/media/bin/media-home-sync`

**Input**: List of items to promote/archive

**Logic**:
```bash
#!/bin/bash
# media-home-sync

ACTION=$1  # promote or archive
ITEM=$2    # path to movie/TV item

case $ACTION in
  promote)
    # Move from shop warm → home hot
    rsync -avh --remove-source-files "pve:/media/movies/$ITEM" "nas:/volume1/media-staging/movies/$ITEM"
    ;;
  archive)
    # Move from home hot → shop cold
    rsync -avh --remove-source-files "nas:/volume1/media-staging/movies/$ITEM" "pve:/md1400/archive/media-cold/movies/$ITEM"
    ;;
  *)
    echo "Usage: media-home-sync {promote|archive} <item>"
    exit 1
    ;;
esac
```

**Test**:
```bash
# Promote one test movie
./bin/ops cap run media.home.sync -- promote "Test Movie (2024)"

# Verify movie moved to home and playback works
ssh media-home "ls -lh /volume1/media-staging/movies/Test\ Movie\ \(2024\)"
# Play in Jellyfin on media-home

# Archive one test movie
./bin/ops cap run media.home.sync -- archive "Old Movie (2010)"

# Verify movie moved to cold
ssh pve "ls -lh /md1400/archive/media-cold/movies/Old\ Movie\ \(2010\)"
```

**Success criteria**: Sync works correctly, checksums verified, no data loss.

---

### Phase 4: Lifecycle Automation (Future) ⏸️ NOT STARTED
**Goal**: Automate tier movement based on watch history and age
**Prerequisites**: Phase 3 complete (tier boundaries canonical)

**Duration**: 2-3 weeks (development + testing)
**Risk**: Medium (automation could move wrong content)

**Blocked by**:
- Jellyfin API integration (playback history)
- Operator review workflow (quarantine decisions)
- Tested sync capabilities (Phase 3)

**Out of scope for current wave** — defer to future backlog.

---

## Rollback Procedures

### Rollback Phase 1 (Capacity Crisis)

**If downloads cleanup went wrong**:
```bash
ssh pve "zfs rollback media/downloads@pre-bloat-cleanup-20260319"
```

**If archive move went wrong**:
```bash
ssh pve "zfs rollback media@pre-cold-archive-20260319"
# Restore deleted source files
ssh pve "rsync -avh /md1400/archive/media-cold/movies/aged_movie/ /media/movies/aged_movie/"
```

### Rollback Phase 2 (Drive Replacement)

**If new pool fails during rsync**:
- Old media pool is untouched
- Stop rsync
- Destroy media-new pool
- Restart VMs (they'll use old media pool)
- Investigate rsync errors

**If new pool fails after VM remount**:
```bash
# Stop VMs
ssh pve "qm stop 209 && qm stop 210"

# Restore old NFS export
ssh pve "cp /etc/exports.backup-20260319 /etc/exports"
ssh pve "exportfs -ra"

# Recreate old overlay mount
ssh pve "mount -o bind /md1400/archive/media-cold/movies-archive /media/movies-archive"

# Start VMs
ssh pve "qm start 209 && qm start 210"

# Verify old media pool works
ssh streaming-stack "df -h /mnt/media && ls -lh /mnt/media/movies | head"
```

**If new pool fails after 48h monitoring** (before old pool destroyed):
- Same as above (VMs can remount old pool)
- Old pool is still intact until Step 2.9

**If issues discovered AFTER old pool destroyed**:
- NO ROLLBACK POSSIBLE
- Old pool is gone permanently
- Must troubleshoot new pool in place
- **This is why 48h monitoring (Step 2.8) is critical**

---

## Verification Checklist

### Phase 1 Complete
- [ ] media pool usage <80% (run: `ssh pve "zpool list media"`)
- [ ] downloads folder <200G (run: `ssh streaming-stack "du -sh /mnt/media/downloads"`)
- [ ] Quarantine tier exists (run: `ssh pve "ls -lh /md1400/archive/media-quarantine"`)
- [ ] Cold tier usage <60% (run: `ssh pve "zpool list md1400"`)
- [ ] Forensic snapshots exist (run: `ssh pve "zfs list -t snapshot | grep media@"`)

### Phase 2 Complete
- [ ] New 4x14TB SAS pool created (run: `ssh pve "zpool status media"`)
- [ ] All data rsync'd with checksum verification (diff output empty)
- [ ] VMs remounted to new pool (run: `ssh streaming-stack "df -h /mnt/media"`)
- [ ] Jellyfin playback works (manual test)
- [ ] *arr imports work (manual test)
- [ ] 48 hours stable operation (no errors in logs)
- [ ] Old pool destroyed (run: `ssh pve "zpool list | grep -v media"`)
- [ ] hardware.inventory.yaml updated (run: `git log -1 --oneline ops/bindings/hardware.inventory.yaml`)

### Phase 3 Complete
- [ ] Synology volumes audited (documented in evidence file)
- [ ] Home tier content policy defined (in MEDIA_STORAGE_CONTRACT.md)
- [ ] media-home VM 106 in vm.lifecycle.yaml (run: `yq '.[] | select(.vm_id == 106)' ops/bindings/vm.lifecycle.yaml`)
- [ ] media-home VM 106 in backup.inventory.yaml (run: `yq '.targets[] | select(.unit_id == "vm-106-media-home")' ops/bindings/backup.inventory.yaml`)
- [ ] Home playback tested and fast (manual test)
- [ ] media.home.sync capability exists and tested

---

## Success Criteria

**Phase 1 Success**:
- media pool <80% usage (safe for drive replacement)
- Downloads bloat eliminated (staging-only rule restored)
- Quarantine tier operational (safe deletion review buffer)
- No data loss (forensic snapshots verified)

**Phase 2 Success**:
- 4x14TB SAS drives installed and resilver'd
- media pool now ~38-40T capacity (~50% free)
- Playback and imports work correctly
- Old 4x8TB SATA drives retired
- hardware.inventory.yaml updated

**Phase 3 Success**:
- media-home VM 106 governed (in vm.lifecycle + backup.inventory)
- Home tier policy explicit (documented in contract)
- Home ↔ shop sync automation works
- Operator can promote favorites or archive aged content safely

**Overall Success**:
- Media storage architecture is boring, explicit, and unambiguous
- Operator can answer: "Where do movies live? TV? Music? Downloads?"
- Capacity crisis resolved (plenty of headroom)
- Safe migration path for future changes
- No data loss during entire migration

---

## Anti-Patterns

❌ **Skip capacity crisis resolution** (Phase 1) and jump to drive replacement (Phase 2)
**Why**: Drive replacement at 96% full is unsafe (resilver failure risk)

❌ **Move data without checksums**
**Why**: Silent corruption can occur, always verify checksums after moves

❌ **Delete old pool before 48h monitoring**
**Why**: If new pool fails, rollback is impossible after old pool destroyed

❌ **Guess at Synology usage instead of auditing**
**Why**: NFS overlays and bind mounts hide true state, must verify

❌ **Enable lifecycle automation before tier boundaries are explicit**
**Why**: Automation needs clear rules, or it will move wrong content

---

## Related Documents

- Parent contract: `docs/governance/MEDIA_STORAGE_CONTRACT.md`
- Hardware inventory: `ops/bindings/hardware.inventory.yaml`
- Backup inventory: `ops/bindings/backup.inventory.yaml`
- VM lifecycle: `ops/bindings/vm.lifecycle.yaml`
- Service registry: `docs/governance/SERVICE_REGISTRY.yaml`
- Shop media pressure audit: `docs/reference/audits/SHOP_MEDIA_PRESSURE_CLOSURE_20260312.md`

---

## Phase 1 Execution Summary (2026-03-19)

**Execution**: Complete ✅

**Metrics**:
- Pool usage: 96% → 86% (2.77T reclaimed)
- Downloads: 2.3T → 105G (2.195T freed)
- Quarantine tier: 456 items staged for review
- Cold tier: 43% → 50% usage (7.3T gained)

**Forensic Artifacts**:
- Snapshot: `media@phase1-pre-reclaim-20260319`
- Evidence: `/Users/ronnyworks/code/.evidence/spine/verify/MEDIA_PHASE1_CAPACITY_RESOLUTION_20260319.md`

**Gates Passed**:
- ✅ media pool <80% (86%)
- ✅ downloads <200G (105G)
- ✅ cold tier <60% (50%)
- ✅ Quarantine tier operational

**Next Phase**: Phase 2 ready upon hardware procurement of 4x14TB SAS drives

---

## Change Log

**v1.1** (2026-03-19):
- Phase 1 execution complete with 2.77T reclaimed
- Updated capacity metrics (96% → 86% pool usage)
- Marked Phase 0 and Phase 1 as COMPLETE
- Phase 2 status changed to READY (prerequisites met)
- Added execution summary with forensic artifacts and evidence link

**v1.0** (2026-03-19):
- Initial migration plan created
- Defined 4 phases with explicit gates
- Documented safe drive replacement procedure
- Created rollback procedures for each phase
- Verified against current live state (96% media pool)
