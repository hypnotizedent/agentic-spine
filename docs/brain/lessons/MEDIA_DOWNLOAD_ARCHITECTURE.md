# Media Download Architecture

> **Status:** authoritative
> **Provenance:** extracted from legacy media source `media-stack/docs/reference/REF_DOWNLOAD_ARCHITECTURE.md` (commit `1ea9dfa`)
> **Extraction loop:** LOOP-MEDIA-LEGACY-EXTRACTION-20260211
> **Last verified:** 2026-02-11
> **Topology:** VM 209 (download-stack), VM 210 (streaming-stack)

---

## Philosophy: Passive & Polished

A set-and-forget archival system that runs 24/7 at the Shop, with Home as an on-demand turbo tap.

1. **Shop 24/7 (Primary):** VM 209 downloads constantly at ~20 MB/s (160 Mbps T-Mobile 5G). Never sleeps.
2. **Home On-Demand (Turbo):** LXC 103 on proxmox-home with 1 Gbps fiber. Only opened for massive backfills, otherwise stays off.
3. **CLI First:** Scripts and API calls over UI clicks.
4. **Data Driven:** Huntarr cycles through missing content automatically — no manual search needed.

---

## Download Pipeline

| Role | Host | Speed | Priority | Status |
|------|------|-------|----------|--------|
| **Primary (24/7)** | download-stack (VM 209, Shop) | ~20 MB/s | 1 | Always on |
| **Turbo/Bulk** | download-home (LXC 103, Home) | 100+ MB/s | 2 | On demand only |

### How Turbo Mode Works

1. In Radarr/Sonarr Settings > Download Clients, set `SABnzbd-Home` to Priority 1.
2. Downloads fly at 100+ MB/s, then rsync to Shop NFS.
3. When done, set priority back to 2 (or disable entirely).

Use for large backfills only — Home bandwidth is shared with the household.

---

## Automated Search: Huntarr

Huntarr cycles through missing content on VM 209, avoiding the bulk-search rule (Rule 1 in MEDIA_CRITICAL_RULES.md).

| App | Items/Cycle | Cycle Interval |
|-----|-------------|---------------|
| Radarr | 5 movies | 15 min |
| Sonarr | 1 episode | 15 min |
| Lidarr | 1 album | 15 min |

**Note:** Huntarr is currently in the "intentionally stopped" group on VM 209. Start it when active searching is wanted:
```bash
ssh download-stack 'sudo docker start huntarr'
```

---

## Service Placement (Post-Split)

**VM 209 — download-stack (192.168.1.209)**
- Radarr, Sonarr, Lidarr, Prowlarr (content management)
- SABnzbd, qBittorrent (download clients)
- Recyclarr, Unpackerr, Decypharr (post-processing)
- Huntarr, Tdarr, Slskd (stopped — start as needed)
- Autopulse, Crosswatch, CrowdSec (automation + security)
- NFS media mount: **rw** (downloads write here)

**VM 210 — streaming-stack (192.168.1.210)**
- Jellyfin, Navidrome (playback)
- Jellyseerr (request UI)
- Bazarr (subtitles)
- Wizarr, Spotisub, Homarr, Subgen (supporting)
- NFS media mount: **ro** (read-only — streaming never writes media)

---

## Storage Layout

```
pve (192.168.1.184) NFS exports:

/media                              → Both VMs mount this
├── downloads/complete/             → SABnzbd landing zone (VM 209 rw)
├── downloads/incomplete/           → In-progress downloads
├── movies/                         → Radarr library (1,272+ dirs)
├── tv/                             → Sonarr library
├── music/                          → Lidarr library (218+ dirs)
└── recycle/                        → *arr recycle bins

/tank/docker/download-stack         → VM 209 only
└── volumes/{radarr,sonarr,...}/    → Container configs

/tank/docker/streaming-stack        → VM 210 only
└── volumes/{jellyfin,navidrome,...}/ → Container configs
```

---

## Cross-References

| Document | Relationship |
|----------|-------------|
| `MEDIA_CRITICAL_RULES.md` | Safety constraints for download operations |
| `MEDIA_STACK_LESSONS.md` | NFS + SQLite architecture patterns |
| `MEDIA_RECOVERY_RUNBOOK.md` | Recovery procedures for both VMs |
| `ops/staged/download-stack/docker-compose.yml` | VM 209 service definitions |
| `ops/staged/streaming-stack/docker-compose.yml` | VM 210 service definitions |

---

_Extracted: 2026-02-11_
_Loop: LOOP-MEDIA-LEGACY-EXTRACTION-20260211_
