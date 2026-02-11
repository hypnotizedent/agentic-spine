---
status: active
owner: "@ronny"
created: 2026-02-11
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

**Option A (compose volume fix — recommended):** Add explicit bind mounts to the download-stack compose file so the old *arr paths resolve correctly. No app-level reconfiguration needed.

```yaml
# Add to radarr volumes:
- /mnt/media/movies:/movies
- /mnt/media/downloads:/downloads

# Add to sonarr volumes:
- /mnt/media/tv:/tv
- /mnt/media/downloads:/downloads

# Add to lidarr volumes:
- /mnt/media/music:/music
- /mnt/media/downloads:/downloads
```

**Autopulse fix:** Update env vars `REWRITE__TO` from `/data/media/*` to `/media/*`.

**Swaparr fix:** Restart crashed containers, investigate exit 255 if they crash again.

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Audit + gap registration | done |
| P1 | Fix compose volumes (radarr/sonarr/lidarr) | pending |
| P2 | Fix autopulse path rewrites | pending |
| P3 | Restart swaparr-lidarr + swaparr-sonarr | pending |
| P4 | Verify root folder accessibility via *arr API | pending |
| P5 | End-to-end pipeline test (trigger download, verify import + Jellyfin scan) | pending |
| P6 | Update SSOT docs (MEDIA_PIPELINE_ARCHITECTURE.md, MEDIA_DOWNLOAD_ARCHITECTURE.md) | pending |

## Acceptance Criteria

1. [ ] Radarr `/movies` accessible=true (API check)
2. [ ] Sonarr `/tv` accessible=true (API check)
3. [ ] Lidarr `/music` accessible=true (API check)
4. [ ] Autopulse rewrite targets match Jellyfin mount paths
5. [ ] swaparr-lidarr + swaparr-sonarr running
6. [ ] At least one download imports successfully end-to-end
7. [ ] spine.verify passes
8. [ ] SSOT docs updated with correct path mappings

## Commits

| Commit | Description |
|--------|-------------|

## Receipts

| Receipt | Result |
|---------|--------|
