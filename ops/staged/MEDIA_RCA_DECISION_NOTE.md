# Media Stack RCA Decision Note

| Field | Value |
|-------|-------|
| Loop | `LOOP-MEDIA-STACK-RCA-20260205` |
| Generated | `2026-02-07T20:57Z` |
| Updated | `2026-02-07T19:28Z` |
| Severity | high |

## Current State

**Media-stack is UP and stable (post-recovery).** VM 201 recovered via `qm stop 201 && qm start 201` on pve at ~2026-02-07T18:57Z. Quick-wins applied immediately after restart.

| Metric | Pre-Recovery | Post-Recovery (T+32m) |
|--------|-------------|----------------------|
| Load | 1882.02 | 2.76 |
| iowait | 43% | 48% |
| Memory | 6.4GB/15GB | 3.6GB/15GB |
| Containers (running) | 32 (zombied) | 27 (healthy) |
| Containers (stopped) | 0 | 5 (quick-win) |
| SSH | unreachable | reachable |
| NFS mounts | deadlocked | functional |

**Note:** iowait remains high (~48%) even post-recovery. This is the NFS architectural problem, not load-related. Quick-wins reduced load but did not address the I/O bottleneck.

## Root Causes (from loop evidence + live diagnosis)

| # | Cause | Severity | Quick-Win? | Status |
|---|-------|----------|-----------|--------|
| 1 | SQLite on NFS causing database locks | HIGH | No — architectural (move DBs to local SSD) | OPEN — deferred to arch loop |
| 2 | Tailscale → NFS → Docker boot dependency race | HIGH | Partial — add `systemd` ordering | OPEN — deferred to arch loop |
| 3 | 32 containers on 16GB VM resource exhaustion | MEDIUM | Yes — disable Tdarr/Huntarr + downloads | DONE |
| 4 | Tdarr/downloads saturating NFS I/O | MEDIUM | Yes — reduce concurrency or disable | DONE |

## Quick-Win Assessment

**Quick wins applied and holding.** Five containers disabled:

| Container | Purpose | Restart Policy |
|-----------|---------|---------------|
| tdarr | Media transcoding (heavy NFS I/O) | `no` |
| huntarr | Missing media hunter | `no` |
| sabnzbd | Usenet downloader (NFS write target) | `no` |
| qbittorrent | Torrent client (NFS write target) | `no` |
| slskd | Soulseek client | `no` |

Stopping download clients (sabnzbd, qbittorrent, slskd) in addition to tdarr/huntarr further reduces NFS write pressure. This was a tactical decision beyond the original recommendation.

## Decision: Quick-Win First, Then Split

**Executed.** Quick-wins applied. Architecture loop created as `LOOP-MEDIA-STACK-ARCH-20260208`.

## Split-Loop Status

| Loop | Scope | Status |
|------|-------|--------|
| `LOOP-MEDIA-STACK-RCA-20260205` | Diagnosis + quick-wins | Closing gate: 24h stability from T+0 (~2026-02-08T19:00Z) |
| `LOOP-MEDIA-STACK-ARCH-20260208` | SQLite migration, boot ordering, VM right-sizing | Created, pending |

## Blockers (Resolved)

| Blocker | Status | Resolution |
|---------|--------|-----------|
| Media-stack unreachable | RESOLVED | VM 201 restarted via `qm stop/start` on pve |
| No SSH target in ssh.targets.yaml | RESOLVED | GAP-OP-010 fixed — media-stack added (100.117.1.53, root, shop/pve) |

## Completed Actions

1. **Recover media-stack** — DONE. `qm stop 201 && qm start 201` via pve
2. **Apply quick-wins** — DONE. 5 containers stopped with restart=no
3. **Add ssh.targets.yaml binding** — DONE. GAP-OP-010 fixed
4. **Create arch loop** — DONE. `LOOP-MEDIA-STACK-ARCH-20260208`

## NFS Topology (P0 Evidence for Arch Loop)

**Compose project:** `/home/media/stacks/media-stack`

**NFS mounts (fstab):**

| NFS Source (pve) | Local Mount | Purpose |
|-----------------|-------------|---------|
| `/tank/docker/media-stack` | `/mnt/docker` | Container config/volumes |
| `/media` | `/mnt/media` | Media files (movies/tv/music/downloads) |

Both use `x-systemd.requires=tailscaled.service` (Tailscale must be up before mount).

**SQLite databases — ALL on NFS via `/config` bind mounts:**

| Container | Config Path (NFS) | Database |
|-----------|-------------------|----------|
| radarr | `/mnt/docker/volumes/radarr/config/` | radarr.db (+ WAL) |
| sonarr | `/mnt/docker/volumes/sonarr/config/` | sonarr.db |
| prowlarr | `/mnt/docker/volumes/prowlarr/config/` | prowlarr.db |
| jellyfin | `/mnt/docker/volumes/jellyfin/config/` | jellyfin.db |
| lidarr | `/mnt/docker/volumes/lidarr/config/` | lidarr.db |
| trailarr | `/mnt/docker/volumes/trailarr/config/` | trailarr.db (active WAL confirmed via lsof) |

**Note:** `/opt/appdata/*.db` files exist on local disk but are **stale copies**, not actively used. All containers bind-mount config from NFS.

**Boot dependency gap:** Docker systemd unit depends on `network-online.target` but has **no dependency on NFS mounts**. If Docker starts before NFS automounts complete, containers fail to bind-mount their config dirs. This is root cause #2.

## Remaining

5. **Close RCA loop** — gate: 24h stability confirmed (~2026-02-08T19:00Z)
   - Check: SSH reachable, load < 10, no zombie containers, all 27 containers healthy
