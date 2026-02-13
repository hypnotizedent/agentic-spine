# Media Stack Lessons

> **Status:** reference
> **Provenance:** spine-native
> **Source Loops:** LOOP-MEDIA-STACK-RCA-20260205, LOOP-MEDIA-STACK-ARCH-20260208
> **Last verified:** 2026-02-08

Hard-won knowledge from media stack crash investigation and NFS→local DB migration.

---

## SQLite on NFS — The Core Anti-Pattern

### Why It Fails
- SQLite uses file-level locking (fcntl) which is unreliable over NFS
- WAL (Write-Ahead Logging) mode requires shared memory which NFS does not support
- NFS hard mounts + sync mean every I/O hiccup stalls ALL container writes
- Result: database locks, WAL corruption, 48% iowait, daily VM crashes

### The Fix Pattern: Symlink to Local Disk
```bash
docker stop <service>
mkdir -p /opt/appdata/<service>
mv <nfs-path>/<file>.db /opt/appdata/<service>/<file>.db
ln -sfn /opt/appdata/<service>/<file>.db <nfs-path>/<file>.db
chown -R 1000:1000 /opt/appdata/<service>
docker start <service>
```

### Critical Requirement: Bind Mount Visibility
Symlinks from NFS to `/opt/appdata/` only work if the container has
`/opt/appdata:/opt/appdata` as a volume bind mount. Without this, the
container follows the symlink but can't resolve the target (different
mount namespace).

**Services that already had the mount (Dec 23 setup):**
radarr, sonarr, lidarr, prowlarr, jellyfin

**Services that did NOT and required compose update (Feb 8):**
trailarr, posterizarr

**Failure mode without bind mount:** Container starts but crashes with
`sqlite3.OperationalError: unable to open database file` or alembic
migration failures. The error does NOT mention symlinks — it looks like
a missing file.

### What's Now on Local Disk (16 total)

| Service | Main DB (Dec 23) | Logs/Secondary (Feb 8) |
|---------|------------------|------------------------|
| radarr | radarr.db (268MB) | logs.db (90MB) |
| sonarr | sonarr.db (4MB) | logs.db (2.2MB) |
| lidarr | lidarr.db (411MB) | — |
| prowlarr | prowlarr.db (29MB) | logs.db (3.6MB) |
| jellyfin | jellyfin.db (148MB) | introskipper.db (1.4MB) |
| trailarr | — | trailarr.db (124KB) + logs.db (388KB) |
| posterizarr | — | 5 DBs (~250KB) |

---

## NFS Permission Warnings

### `mv` from NFS to ext4
```
mv: preserving permissions for '/opt/appdata/radarr/logs.db': Operation not supported
```
**Benign.** File moves successfully. NFS extended attributes can't transfer
to ext4 but the file data and standard POSIX permissions are preserved.

### `cp -a` from NFS to ext4
Same warning but `cp -a` exits with code 1 due to the permission
preservation failure. This breaks `&&` chains.

**Workaround:** Use `cp` without `-a` flag, or use `mv` (preferred for
migrations since it avoids doubling disk usage).

---

## Diagnostic Patterns

### SSH Identity Rule (media-stack)

- Do not assume `root` SSH works on `media-stack`. Use the SSOT binding in `ops/bindings/ssh.targets.yaml`.
- If the SSH user is non-root, rely on passwordless sudo for root-required operations (`sudo -n ...`).
- Governance trace: `GAP-OP-025` in `ops/bindings/operational.gaps.yaml`.

Verification (non-mutating):
```bash
ssh -G media-stack | rg '^(user|hostname|port) '
ssh media-stack 'whoami; hostname; sudo -n true && echo SUDO_OK'
```

### Key Metric: iowait
- `vmstat 1 5` — look at the `wa` column
- Baseline (all DBs on NFS): **48%**
- After Phase A (logs + secondary DBs moved): **0-5%**
- Threshold for concern: > 20%

### Quick Health Check
```bash
ssh media-stack "uptime && docker ps --filter status=dead -q | wc -l && docker ps --filter health=unhealthy --format '{{.Names}}'"
```

### Container Recovery After Migration
- Some services need 30-60s after restart for healthcheck to pass
- `trailarr` is particularly slow (uses alembic migrations on startup)
- Don't panic at `(health: starting)` — wait and re-check

---

## Root Cause Chain (RCA Summary)

| # | Cause | Severity | Resolution |
|---|-------|----------|------------|
| 1 | SQLite on NFS | HIGH | Symlink to local (Phase A — done) |
| 2 | Tailscale → NFS → Docker boot race | HIGH | systemd ordering (Phase C — pending) |
| 3 | 32 containers on 16GB VM | MEDIUM | Quick-win: 5 containers disabled |
| 4 | Tdarr/downloads saturating NFS I/O | MEDIUM | Quick-win: stopped with restart=no |

### Quick-Win Containers (stopped, restart=no)
- tdarr — media transcoding (heavy NFS I/O)
- huntarr — missing media hunter
- sabnzbd — Usenet downloader
- qbittorrent — torrent client
- slskd — Soulseek client

---

## Boot Ordering (Phase C)

### The Problem
Docker's systemd unit depends on `network-online.target` but has NO
dependency on NFS mounts. If Docker starts before NFS automounts complete,
containers bind-mount empty directories and crash.

### The Fix
Systemd drop-in at `/etc/systemd/system/docker.service.d/nfs-dependency.conf`:
```ini
[Unit]
After=mnt-docker.mount mnt-media.mount
Requires=mnt-docker.mount mnt-media.mount
```

### Why `Requires=` Not Just `After=`
- `After=` only controls ordering — if the mount fails, Docker still starts
- `Requires=` ensures Docker won't start if either NFS mount fails
- Combined: Docker starts after NFS AND only if NFS is healthy

### fstab Already Handles Tailscale
The NFS entries use `x-systemd.requires=tailscaled.service`, so the
full boot chain is: `tailscaled → NFS mounts → Docker → containers`.

---

## Decision Record

### Why Phase A Before 24h Gate
The 24h stability gate was set at ~Feb 8 19:00Z. Phase A was executed at
Feb 8 02:48Z (~8h into the gate). Rationale:
- VM was demonstrably stable (load 0.13, 27/27 healthy)
- Phase A uses the same symlink pattern proven since Dec 23
- The operation is individually reversible per service
- Waiting 16h provided no additional safety signal

### Phase B Assessment
With iowait at 0-5% after Phase A, Phase B (dedicated data disk + full
config migration off NFS) may be unnecessary. The remaining NFS traffic
is config reads and temp files — not write-heavy. Monitor for 1 week
before deciding.

---

## Rollback Pattern

```bash
# Per-service rollback (reverses one symlink)
docker stop <service>
rm -f <nfs-path>/<file>.db                        # remove symlink
cp /opt/appdata/<service>/<file>.db <nfs-path>/    # copy back
docker start <service>
```

Keep `/opt/appdata/` copies for at least 7 days after migration as
rollback targets.

---

## Cross-References

| Document | Relationship |
|----------|--------------|
| `ops/staged/MEDIA_RCA_DECISION_NOTE.md` | RCA diagnosis + quick-win record |
| `ops/staged/MEDIA_STACK_ARCH_PHASE_A_PLAYBOOK_20260207.md` | Execution playbook |
| `mailroom/state/loop-scopes/LOOP-MEDIA-STACK-ARCH-20260208.scope.md` | Architecture scope (Phase B/C pending) |
| `mailroom/state/loop-scopes/LOOP-MEDIA-STACK-SPLIT-20260208.scope.md` | Future VM split (blocked by ARCH) |
| `ops/bindings/docker.compose.targets.yaml` | Media stack compose path |
| `ops/bindings/ssh.targets.yaml` | Download-stack (100.107.36.76) + streaming-stack (100.123.207.64) SSH targets |
| `ops/bindings/operational.gaps.yaml` | GAP-OP-021 through GAP-OP-024 |

---

_Extracted from LOOP-MEDIA-STACK-RCA-20260205 + LOOP-MEDIA-STACK-ARCH-20260208_
_Canonicalized: 2026-02-08_
