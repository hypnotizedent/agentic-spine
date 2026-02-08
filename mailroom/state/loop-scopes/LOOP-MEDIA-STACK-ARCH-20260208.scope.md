# LOOP-MEDIA-STACK-ARCH-20260208 — Scope Document

| Field | Value |
|-------|-------|
| Created | 2026-02-07T21:00Z |
| Scoped | 2026-02-07T22:00Z |
| Owner | @ronny |
| Severity | high |
| Parent | LOOP-MEDIA-STACK-RCA-20260205 |
| Blocked by | None (RCA closed 2026-02-08) |

## Problem Statement

Media-stack (VM 201) crashes daily due to SQLite database corruption and NFS
I/O saturation. RCA identified three root causes:

1. **SQLite on NFS** — database locks and WAL corruption over NFS
2. **Boot race** — Docker starts before NFS mounts are ready
3. **Resource exhaustion** — 32 containers on 16GB VM with shared NFS I/O

Quick-wins (5 containers stopped, `restart=no`) reduced load from 1882 to ~2.5
and freed 12GB RAM. But **48% iowait persists** — the NFS I/O problem is structural.

## Current Architecture (Discovered 2026-02-07)

### VM 201 (media-stack)
- 4 cores (host CPU), 16GB RAM, 80GB boot disk on `local-lvm`
- Boot disk: 77GB total, 48GB used, 26GB free (66%)
- Docker root: `/var/lib/docker` on boot disk (overlay2)
- No secondary data disk

### NFS Mounts (via Tailscale, hard mount, NFSv4.2)
| NFS Source (pve) | Mount | Size | Purpose |
|-----------------|-------|------|---------|
| `/tank/docker/media-stack` | `/mnt/docker` | 24.1GB used | Container config/volumes |
| `/media` | `/mnt/media` | 9.9TB used | Media files (read-mostly) |

Mount options: `rw,hard,proto=tcp,timeo=600,retrans=2,sec=sys`
fstab: `x-systemd.automount,x-systemd.requires=tailscaled.service`

### Database Layout (Key Discovery)

**5 main databases ALREADY symlinked to local disk (`/opt/appdata/`):**

| Database | Size | NFS path → Local target |
|----------|------|------------------------|
| radarr.db | 268MB | `/mnt/docker/volumes/radarr/config/` → `/opt/appdata/radarr/` |
| lidarr.db | 411MB | `/mnt/docker/volumes/lidarr/config/` → `/opt/appdata/lidarr/` |
| jellyfin.db | 148MB | `/mnt/docker/volumes/jellyfin/config/data/` → `/opt/appdata/jellyfin/` |
| prowlarr.db | 29MB | `/mnt/docker/volumes/prowlarr/config/` → `/opt/appdata/prowlarr/` |
| sonarr.db | 4MB | `/mnt/docker/volumes/sonarr/config/` → `/opt/appdata/sonarr/` |

Symlinks created Dec 23, 2025. All files have recent timestamps — **actively in use.**

**Databases STILL on NFS (the remaining I/O problem):**

| Database | Size | Path | Write Frequency |
|----------|------|------|-----------------|
| radarr logs.db | **106MB** | `/mnt/docker/volumes/radarr/config/` | constant |
| prowlarr logs.db | 3.8MB | `/mnt/docker/volumes/prowlarr/config/` | constant |
| jellyfin introskipper.db | 1.4MB | `/mnt/docker/volumes/jellyfin/config/data/` | periodic |
| trailarr.db | 124KB | `/mnt/docker/volumes/trailarr/` | periodic |
| posterizarr (5 DBs) | ~250KB | `/mnt/docker/volumes/posterizarr/database/` | low |
| huntarr databases | ~16MB | `/mnt/docker/volumes/huntarr/` | stopped (quick-win) |
| sabnzbd history1.db | 3.4MB | `/mnt/docker/volumes/sabnzbd/config/admin/` | stopped (quick-win) |

**Plus:** All non-DB config files, logs, and temporary files for all 27 running
containers are on NFS via `/mnt/docker/volumes/`.

### Why 48% iowait persists

The symlink fix moved the 5 biggest databases off NFS but:
1. **logs.db files** (especially radarr 106MB) are constantly written on NFS
2. **All container config I/O** (reads, writes, temp files) goes through NFS
3. **NFS over Tailscale WireGuard** adds latency to every I/O operation
4. **hard mount + sync** means every NFS hiccup stalls all container I/O

## Proposed Architecture (3 Phases)

### Phase A: Move remaining databases + logs to local — COMPLETE (2026-02-08)

Executed 2026-02-08T02:48Z. Migrated 11 database files from NFS to `/opt/appdata/` with symlinks:

| Service | Files Moved | Notes |
|---------|-------------|-------|
| radarr | logs.db (90MB) | Biggest write source |
| prowlarr | logs.db (3.6MB) | |
| sonarr | logs.db (2.2MB) | Bonus target (not in original plan) |
| trailarr | trailarr.db (124KB) + logs/logs.db (388KB) | Required /opt/appdata bind mount added to compose |
| posterizarr | 5 DBs (~250KB total) | Required /opt/appdata bind mount added to compose |
| jellyfin | introskipper.db (1.4MB) | |

**Result:** iowait dropped from **48% to 0-5%** (target was < 20%). All 27 containers healthy.
**Compose changes:** Added `/opt/appdata:/opt/appdata` volume mount to trailarr and posterizarr services.

### Phase B: Add dedicated data disk + move config volume to local

1. Create a 50GB virtual disk on `tank-vms` ZFS pool (16TB available)
2. Attach to VM 201 as `scsi1`
3. Format as ext4, mount at `/opt/stacks-data`
4. Move container config from NFS (`/mnt/docker/volumes/*`) to local disk
5. NFS mount `/mnt/docker` retained as read-only fallback or removed entirely
6. Keep `/mnt/media` on NFS (read-mostly, large files are fine on NFS)

**Expected impact:** Eliminate NFS for all config I/O. Only media files on NFS.
**Risk:** Medium — must stop all containers, copy data, update compose bind
mounts, restart. Downtime: 10-30 min.
**Acceptance:** iowait < 5% during normal operation.

### Phase C: Boot ordering + systemd hardening

1. Add `After=mnt-media.mount` to Docker systemd unit (not mnt-docker if
   config moves to local)
2. Or create a `media-stack-ready.target` that requires NFS + Tailscale + Docker
3. Add healthcheck to compose that verifies NFS is mounted before starting
   containers that need media access

**Expected impact:** Eliminate boot race condition that causes container failures.
**Risk:** Low — systemd unit override.
**Acceptance:** VM 201 survives clean reboot with all containers healthy.

## What This Loop Does NOT Cover

- **VM split (209/210)** — deferred to a future loop. Right-sizing the VM
  split requires knowing which containers stay after quick-win evaluation.
  The 5 stopped containers may or may not come back.
- **Quick-win evaluation** — which of the 5 stopped containers to permanently
  remove vs restart. Separate decision after arch stabilizes.
- **media pool SMR drive replacement** — discovered but separate concern.

## Ordering Constraints

1. ~~**Blocked by RCA closure**~~ — RCA closed 2026-02-08T02:45Z.
2. **Phase A complete** — executed 2026-02-08T02:48Z, iowait 48% → 0-5%.
3. **Phase B requires VM 201 downtime** — coordinate with any active media
   consumption. May be unnecessary given Phase A iowait results.
4. **Phase C can be done at any time** (systemd changes take effect on reboot).

## Pre-Staged Artifact

- `ops/staged/MEDIA_STACK_ARCH_PHASE_A_PLAYBOOK_20260207.md`
  - Step-by-step Phase A mutation playbook + rollback (ready after RCA closure gate).

## PVE Context (from Shop Baseline 2026-02-07)

| Resource | Value |
|----------|-------|
| PVE version | 9.1.4 |
| Host RAM | 188GB (103GB available) |
| Host CPU | 32 cores, load ~2.2 |
| local-lvm | 857GB total, 45% used |
| tank-vms | 16TB available |
| media pool | 29.1T, 57% capacity, RAIDZ1 4x 8TB SMR |
| tank pool | 29.1T, 25% capacity, RAIDZ2 8x 4TB SAS |
| Vzdump | Daily 02:00, VMs 200-203, zstd, tank-backups |
