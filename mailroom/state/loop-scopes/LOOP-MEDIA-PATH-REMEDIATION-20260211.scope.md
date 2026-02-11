---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-MEDIA-PATH-REMEDIATION-20260211
severity: critical
---

# Loop Scope: LOOP-MEDIA-PATH-REMEDIATION-20260211

## Goal

Fix the broken media import pipeline caused by the media stack split (VM 201 → VM 209/210). Root folder paths in Radarr, Sonarr, and Lidarr don't match their container volume mounts, and autopulse path rewrites target non-existent Jellyfin paths. Restore full request-to-playback flow.

## Gap Reference

- GAP-OP-109: *arr root folder path mismatch + autopulse rewrite + swaparr crashes

## Current State (Broken)

| Issue | Service | Expected Path | Actual Path | Impact |
|-------|---------|---------------|-------------|--------|
| Root folder | Radarr | `/movies` | `/media/movies` | Import fails, `accessible: false` |
| Root folder | Sonarr | `/tv` | `/media/tv` | Import fails, `accessible: false` |
| Root folder | Lidarr | `/music` | `/media/music` | Import fails, `accessible: false` |
| Path rewrite | Autopulse → Jellyfin | `/data/media/*` | `/media/*` | Scan notifications silent fail |
| Crashed | swaparr-lidarr | running | exit 255 | Stalled download swapping broken |
| Crashed | swaparr-sonarr | running | exit 255 | Stalled download swapping broken |

**Root cause:** The monolithic compose (VM 201) mapped media types individually (`/mnt/media/movies:/movies`). The split compose maps the parent (`/mnt/media:/media`) but *arr databases still reference the old paths.

## Target State

- All three *arr root folders report `accessible: true`
- Completed downloads import successfully to library
- Autopulse scan notifications use correct Jellyfin paths (`/media/*`)
- swaparr-lidarr and swaparr-sonarr running
- Full pipeline verified: request → download → import → Jellyfin scan

## Fix Strategy

**Option A (compose volume fix — applied):** Added explicit bind mounts to the download-stack compose file so the old *arr paths resolve correctly. No app-level reconfiguration needed.

```yaml
# Added to radarr volumes:
- /mnt/media/movies:/movies
- /mnt/media/downloads:/downloads

# Added to sonarr volumes:
- /mnt/media/tv:/tv
- /mnt/media/downloads:/downloads

# Added to lidarr volumes:
- /mnt/media/music:/music
- /mnt/media/downloads:/downloads
```

**Autopulse fix:** Updated env vars `REWRITE__TO` from `/data/media/*` to `/media/*`.

**Swaparr fix:** Restarted via `docker compose up -d` — both running.

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Audit + gap registration | done |
| P1 | Fix compose volumes (radarr/sonarr/lidarr) | done |
| P2 | Fix autopulse path rewrites | done |
| P3 | Restart swaparr-lidarr + swaparr-sonarr | done |
| P4 | Verify root folder accessibility via *arr API | done |
| P5 | End-to-end pipeline test (trigger download, verify import + Jellyfin scan) | deferred (manual) |
| P6 | Update SSOT docs (MEDIA_PIPELINE_ARCHITECTURE.md, MEDIA_DOWNLOAD_ARCHITECTURE.md) | done |

## Acceptance Criteria

1. [x] Radarr `/movies` accessible=true (API check)
2. [x] Sonarr `/tv` accessible=true (API check)
3. [x] Lidarr `/music` accessible=true (API check)
4. [x] Autopulse rewrite targets match Jellyfin mount paths (`/media/*`)
5. [x] swaparr-lidarr + swaparr-sonarr running
6. [ ] At least one download imports successfully end-to-end (deferred — manual verification)
7. [x] spine.verify passes (D1-D70)
8. [x] SSOT docs updated with correct path mappings

## Commits

| Commit | Description |
|--------|-------------|
| c5a05f1 | gov: register GAP-OP-109 + loop scope |
| e14e964 | fix: restore *arr root folders, autopulse rewrites, SSOT docs, close GAP-OP-109 |

## Receipts

| Receipt | Result |
|---------|--------|
| RCAP-20260211-185102__spine.verify__Rk5d037337 | PASS (D1-D70) |

## Runtime Changes (VM 209)

Compose file edited on VM 209 at `/opt/stacks/download-stack/docker-compose.yml`:
- Added `/mnt/media/movies:/movies` + `/mnt/media/downloads:/downloads` to radarr
- Added `/mnt/media/tv:/tv` + `/mnt/media/downloads:/downloads` to sonarr
- Added `/mnt/media/music:/music` + `/mnt/media/downloads:/downloads` to lidarr
- Changed autopulse `REWRITE__TO` from `/data/media/*` to `/media/*`
- Backup at `/opt/stacks/download-stack/docker-compose.yml.bak-20260211`

Containers recreated: radarr, sonarr, lidarr, autopulse, swaparr-lidarr, swaparr-sonarr

## Open Item

P5 (end-to-end import test) deferred to manual verification — the next queued download that completes in SABnzbd should auto-import via the *arr apps now that root folders are accessible. Radarr shows 34 unmapped folders already visible at `/movies` (previously stuck downloads now importable).
