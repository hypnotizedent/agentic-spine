# Media Stack Analysis & Plan

**Created:** 2026-02-16
**Status:** planning

## Current State

### Infrastructure
| VM ID | Hostname | Role | IP | Services |
|-------|----------|------|-----|----------|
| 209 | download-stack | media-download | 192.168.1.209 | *arr stack, downloaders |
| 210 | streaming-stack | media-streaming | 192.168.1.210 | Jellyfin, Navidrome, etc. |

### Bindings
| File | Lines | Purpose |
|------|-------|---------|
| `media.services.yaml` | ~150 | Single SSOT for all services |

### Capabilities (7)
| Capability | Type | Purpose |
|------------|------|---------|
| `media.health.check` | read-only | Health probes for all services |
| `media.service.status` | read-only | Container status from docker |
| `media.nfs.verify` | read-only | NFS mount health |
| `media.metrics.today` | read-only | Today's Radarr imports |
| `media.stack.restart` | mutating | Restart compose stacks |
| `media.backup.create` | mutating | Config volume snapshots |
| `recyclarr.sync` | mutating | Quality profile sync |

### Drift Gates (5)
- D106: media-port-collision-lock
- D107: media-nfs-mount-lock
- D108: media-health-endpoint-parity-lock
- D109: media-compose-config-match-lock
- D110: media-ha-duplicate-audit-lock

## Pain Points

### 1. Fragmented Status
`media.health.check` + `media.service.status` + `media.nfs.verify` are separate.
Need to run 3 commands to get full picture.

### 2. No Unified Dashboard
HA has `ha.status` — media should have `media.status` showing:
- VM reachability
- Service counts (healthy/unhealthy)
- NFS status
- Storage (disk usage on /mnt/media)
- Open media-related gaps

### 3. No Quick Refresh
HA has `ha.refresh` — media should have `media.refresh` to:
- Verify VMs reachable
- Refresh service status cache (if any)
- Verify NFS mounts

### 4. Missing Service Categories
Current binding has categories but no summary counts. Hard to see at a glance:
- How many management services?
- How many downloaders?
- How many infrastructure services?

## Proposed Improvements

### A. media.status — Unified Dashboard (HIGH VALUE)

One command showing:
```
┌─ VM STATUS ──────────────────────────────────────────────────────────────┐
│  download-stack (209)    ✓ UP    192.168.1.209
│  streaming-stack (210)   ✓ UP    192.168.1.210
└──────────────────────────────────────────────────────────────────────────┘

┌─ SERVICES ───────────────────────────────────────────────────────────────┐
│  download-stack:   22 total | 18 running | 3 exited | 1 error
│  streaming-stack:  10 total | 10 running | 0 exited | 0 errors
│
│  By Category:
│    management:     4 (radarr, sonarr, lidarr, prowlarr)
│    download:       3 (sabnzbd, qbittorrent, slskd)
│    streaming:      2 (jellyfin, navidrome)
│    subtitles:      3 (bazarr*, subgen, decypharr)
│    infrastructure: 4 (watchtower*, node-exporter*)
└──────────────────────────────────────────────────────────────────────────┘

┌─ NFS ────────────────────────────────────────────────────────────────────┐
│  download-stack:   rw    ✓ OK    8.4T free
│  streaming-stack:  ro    ✓ OK    8.4T free
└──────────────────────────────────────────────────────────────────────────┘

┌─ STORAGE ────────────────────────────────────────────────────────────────┐
│  pve:/media:       8.4T free / 12.3T total (68% used)
└──────────────────────────────────────────────────────────────────────────┘
```

**Implementation:**
- New script: `ops/plugins/ha/bin/media-status` (actually media plugin)
- Aggregates: VM ping, service status, NFS verify, disk usage
- No new bindings needed

### B. media.refresh — Quick Health Refresh (MEDIUM VALUE)

Run all verification capabilities in sequence:
- `media.health.check` — probe all endpoints
- `media.service.status` — refresh container status
- `media.nfs.verify` — verify mounts

Shows pass/fail summary like `ha.refresh`.

**Implementation:**
- New script: `ops/plugins/media/bin/media-refresh`
- Wrapper around existing capabilities

### C. Service Summary in Binding (LOW VALUE)

Add summary section to `media.services.yaml`:
```yaml
summary:
  download-stack:
    total: 22
    running: 18
    parked: 2
    stopped: 1
  streaming-stack:
    total: 10
    running: 10
```

Updated by `media.service.status` or `media.refresh`.

## Scope Decision

**Recommend:** A only (media.status)

Why:
- Media is already simpler than HA (1 binding vs 17)
- `media.health.check` already exists and works well
- `media.service.status` already exists and works well
- The gap is visibility — need a unified dashboard
- `media.refresh` is lower value since there's no binding drift problem

## Files to Create/Modify

### media.status
- `ops/plugins/media/bin/media-status` (new)
- `ops/capabilities.yaml` (register media.status)
- `ops/bindings/capability_map.yaml` (add mapping)
- `ops/plugins/MANIFEST.yaml` (add capability)

## Success Criteria

1. `./bin/ops cap run media.status` shows complete media picture
2. Dashboard includes: VM status, service counts, NFS health, storage
3. Replaces need to run 3 separate commands for status check
