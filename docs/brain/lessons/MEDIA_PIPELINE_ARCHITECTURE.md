# Media Pipeline Architecture

> **Status:** authoritative
> **Provenance:** extracted from `ronny-ops/media-stack/docs/reference/REF_MEDIA_PIPELINE.md`
> **Extraction loop:** LOOP-MEDIA-LEGACY-EXTRACTION-20260211
> **Last verified:** 2026-02-11
> **Topology:** VM 209 (download-stack), VM 210 (streaming-stack)

Operational data flow for the media stack. Covers request-to-playback pipeline,
cross-VM connectivity, and service dependencies.

---

## Request Flow (User → Download → Playback)

```
1. User requests movie/show via Jellyseerr (VM 210, :5055)
   │
   └──▶ 2. Jellyseerr sends to Radarr (VM 209, :7878) or Sonarr (:8989)
        │   Cross-VM: Jellyseerr→Radarr uses Tailscale (100.107.36.76)
        │
        └──▶ 3. Radarr/Sonarr queries Prowlarr (:9696) for indexers
             │   Same VM (Docker DNS): prowlarr:9696
             │
             └──▶ 4. Prowlarr returns NZB/torrent results
                  │
                  └──▶ 5. Radarr/Sonarr sends to SABnzbd (:8080) or qBittorrent (:8081)
                       │   Same VM (Docker DNS)
                       │
                       └──▶ 6. Client downloads to /mnt/media/downloads/complete/
                            │
                            └──▶ 7. Radarr/Sonarr imports to library:
                                 │   Movies: /mnt/media/movies/
                                 │   TV: /mnt/media/tv/
                                 │
                                 └──▶ 8. Jellyfin (VM 210) detects via realtime monitor
                                      │   NFS ro mount sees new files immediately
                                      │
                                      └──▶ 9. Bazarr (VM 210) fetches subtitles
                                           │   Cross-VM: Bazarr→Radarr/Sonarr (100.107.36.76)
```

---

## Cross-VM Connectivity Map

All cross-VM communication uses Tailscale IPs:
- VM 209 (download-stack): **100.107.36.76**
- VM 210 (streaming-stack): **100.123.207.64**

| From (Service) | To (Service) | Direction | URL |
|----------------|-------------|-----------|-----|
| Jellyseerr (210) | Radarr (209) | 210→209 | http://100.107.36.76:7878 |
| Jellyseerr (210) | Sonarr (209) | 210→209 | http://100.107.36.76:8989 |
| Bazarr (210) | Radarr (209) | 210→209 | http://100.107.36.76:7878 |
| Bazarr (210) | Sonarr (209) | 210→209 | http://100.107.36.76:8989 |
| Posterizarr (209) | Jellyfin (210) | 209→210 | http://100.123.207.64:8096 |

Intra-VM services use Docker DNS (e.g., `radarr:7878` within VM 209 compose network).

---

## Service Inventory

### VM 209 — download-stack (24 containers)

| Service | Port | Purpose | Health |
|---------|------|---------|--------|
| radarr | :7878 | Movie management | healthcheck |
| sonarr | :8989 | TV management | healthcheck |
| lidarr | :8686 | Music management | healthcheck |
| prowlarr | :9696 | Indexer management | healthcheck |
| sabnzbd | :8080 | Usenet downloads | healthcheck |
| qbittorrent | :8081 | Torrent downloads | healthcheck |
| trailarr | :7667 | Trailer management | healthcheck |
| autopulse | internal | Event automation | healthcheck |
| crosswatch | internal | Cross-service sync | healthcheck |
| decypharr | internal | Encrypted content | healthcheck |
| flaresolverr | :8191 | Cloudflare bypass | no-hc |
| crowdsec | internal | Security | no-hc |
| posterizarr | internal | Poster management | no-hc |
| soularr | internal | Soulseek integration | no-hc |
| swaparr-radarr | internal | Stalled swap (Radarr) | no-hc |
| recyclarr | internal | TRaSH profile sync | no-hc |
| unpackerr | internal | Archive extraction | no-hc |
| watchtower | internal | Container updates | healthcheck |
| node-exporter | :9100 | Prometheus metrics | healthcheck |
| **huntarr** | — | Missing content search | **stopped** |
| **tdarr** | — | Transcoding | **stopped** |
| **slskd** | — | Soulseek client | **stopped** |
| **swaparr-lidarr** | — | Stalled swap | **stopped** |
| **swaparr-sonarr** | — | Stalled swap | **stopped** |

### VM 210 — streaming-stack (10 containers)

| Service | Port | Purpose | Health |
|---------|------|---------|--------|
| jellyfin | :8096 | Media playback | healthcheck |
| navidrome | :4533 | Music streaming | healthcheck |
| jellyseerr | :5055 | Request management | healthcheck |
| bazarr | :6767 | Subtitles | healthcheck |
| wizarr | :5690 | Invite management | healthcheck |
| spotisub | :8766 | Spotify→Navidrome | no-hc |
| homarr | :7575 | Dashboard | healthcheck |
| subgen | internal | Subtitle generation | no-hc |
| watchtower | internal | Container updates | healthcheck |
| node-exporter | :9100 | Prometheus metrics | healthcheck |

---

## Boot Dependency Chain

```
1. pve (Proxmox) running
   └──▶ 2. ZFS pools online (tank, media)
        └──▶ 3. NFS server running on pve
             └──▶ 4. VM boots (cloud-init, qemu-guest-agent)
                  └──▶ 5. Network online (static IP on 192.168.1.0/24)
                       └──▶ 6. NFS mounts via LAN (192.168.1.184)
                            └──▶ 7. Docker starts (systemd requires NFS)
                                 └──▶ 8. Containers start with valid /config
                                      └──▶ 9. Tailscale connects (cross-VM comms)
                                           └──▶ 10. CF tunnel routes resolve
```

Failure at any step cascades downstream.

**Key difference from legacy:** NFS now uses LAN IPs (192.168.1.184) not Tailscale. Docker systemd drop-in at `/etc/systemd/system/docker.service.d/nfs-dependency.conf` ensures Docker waits for NFS.

---

## Public Access (Cloudflare Tunnel)

| Domain | Target | VM |
|--------|--------|-----|
| jellyfin.ronny.works | :8096 | streaming-stack (210) |
| requests.ronny.works | :5055 | streaming-stack (210) |
| music.ronny.works | :4533 | streaming-stack (210) |
| spotisub.ronny.works | :8766 | streaming-stack (210) |

Tunnel runs on infra-core (VM 204), routes to streaming-stack via Tailscale IP.

---

## Music Pipeline

```
Lidarr (209) → SABnzbd (209) → /mnt/media/music/ → Navidrome (210)
```

- Lidarr manages music library on VM 209 (download side).
- Navidrome reads from the same NFS `/mnt/media/music/` on VM 210 (read-only).
- Spotify/Last.fm integration configured on Navidrome (env vars from Infisical).
- Mobile clients connect via Subsonic API (Substreamer, Symfonium, Amperfy).

---

## Quality Profiles

All Radarr movies use profile HD-1080p (ID 4):
- Preferred: WEB-DL 1080p (4-8 GB)
- Fallback: Bluray-1080p (8-15 GB)
- Cutoff: WEB 1080p (stops upgrading once obtained)
- Banned: Remux, 4K, BR-DISK

Language: English only (ID 1). Never use "Original" — causes non-English grabs.

Recyclarr syncs TRaSH Guides profiles automatically. Config authority: `workbench/agents/media/config/recyclarr.yml`.

---

## Cross-References

| Document | Relationship |
|----------|-------------|
| `MEDIA_CRITICAL_RULES.md` | Safety constraints (no bulk search, no trickplay) |
| `MEDIA_DOWNLOAD_ARCHITECTURE.md` | Shop/Home download philosophy |
| `MEDIA_STACK_LESSONS.md` | NFS + SQLite patterns, diagnostic tools |
| `MEDIA_RECOVERY_RUNBOOK.md` | DR procedures for both VMs |
| `receipts/audits/MEDIA_STACK_E2E_TRACE_20260210.md` | Post-split verification receipt |

---

_Extracted: 2026-02-11_
_Loop: LOOP-MEDIA-LEGACY-EXTRACTION-20260211_
