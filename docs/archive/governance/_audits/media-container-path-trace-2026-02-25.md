# Media Container Path Trace Audit

**Date:** 2026-02-25
**Scope:** All running containers on download-stack (VM 209) and streaming-stack (VM 210)
**Trigger:** GAP-OP-908 slskd download path misconfiguration — audit all paths to prevent similar issues
**Method:** `docker inspect` mount enumeration + in-container write test (`touch`/`rm`) + ownership check

---

## Download-Stack (VM 209) — 22 Containers

### HEALTHY (17 containers)
All mounts: HOST_OK, dst=OK, WRITABLE (or RO_OK for read-only)

| Container | Mounts | Status |
|-----------|--------|--------|
| recyclarr | 1 bind | OK |
| soularr | 2 bind | OK |
| slskd | 3 bind | OK (post GAP-OP-908 fix) |
| lidarr | 3 bind | OK |
| huntarr | 1 bind | OK |
| gluetun | 1 bind | OK |
| swaparr-sonarr | 1 bind | OK |
| swaparr-radarr | 1 bind | OK |
| swaparr-lidarr | 1 bind | OK |
| autopulse | 1 bind | OK |
| qbittorrent | 3 bind | OK |
| radarr | 5 bind | OK |
| sonarr | 5 bind | OK |
| sabnzbd | 3 bind | OK |
| trailarr | 3 bind | OK |
| prowlarr | 2 bind | OK |
| crowdsec | 3 bind (1 ro) | OK |

### FINDINGS (5 containers)

| Container | Finding | Gap | Severity |
|-----------|---------|-----|----------|
| **posterizarr** | Runs as nobody:65534, mounts owned 1000:1000 — all 3 rw mounts NOT_WRITABLE | GAP-OP-911 | medium |
| **flaresolverr** | Anonymous volume for /config — fragile on recreate | GAP-OP-912 | low |
| **decypharr** | Anonymous volume for /app — fragile on recreate | GAP-OP-912 | low |
| **watchtower** | Minimal/scratch image — no shell tools for in-container test | N/A (expected) | none |
| **unpackerr** | Minimal Go binary — no shell tools for in-container test | N/A (expected) | none |

### Shared Volume Verification (slskd ↔ soularr)

| Path | slskd Mount | soularr Mount | Host Path | Writable |
|------|------------|---------------|-----------|----------|
| Downloads | `/downloads` | `/downloads/soulseek` | `/mnt/media/downloads/slskd` | YES (1000:1000) |
| Incomplete | `/downloads/incomplete` | — | `/mnt/media/downloads/slskd/incomplete` | YES (1000:1000) |

Post-fix evidence: 2 album directories with 7 FLAC files (~121MB) confirmed in shared volume.

---

## Streaming-Stack (VM 210) — 10 Containers

### HEALTHY (10 containers) — ALL CLEAN

| Container | Mounts | Status |
|-----------|--------|--------|
| bazarr | 3 bind (1 ro) | OK |
| wizarr | 1 bind | OK |
| jellyseerr | 2 bind | OK |
| subgen | 2 bind (1 ro) | OK |
| navidrome | 3 bind (1 ro) | OK |
| spotisub | 1 bind | OK |
| homarr | 4 bind (1 ro) | OK |
| jellyfin | 4 bind (1 ro) | OK |
| node-exporter | 3 bind (all ro) | OK |
| watchtower | 1 bind | OK (minimal image, expected) |

All `/mnt/media` mounts correctly set to `ro` (read-only).
All config volumes under `/mnt/docker/volumes/<service>/` with correct ownership.

---

## Summary

| Stack | Containers | Healthy | Findings | Gaps Filed |
|-------|-----------|---------|----------|------------|
| download-stack | 22 | 17 | 5 (2 real, 3 expected) | GAP-OP-911, GAP-OP-912 |
| streaming-stack | 10 | 10 | 0 | — |
| **Total** | **32** | **27** | **5** | **2** |

**Conclusion:** slskd download path fix (GAP-OP-908) verified working. No other containers have the same class of download-path-to-wrong-volume issue. Two new low/medium gaps filed for unrelated pre-existing findings.
