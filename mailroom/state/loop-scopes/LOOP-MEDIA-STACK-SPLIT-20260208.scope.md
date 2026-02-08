# LOOP-MEDIA-STACK-SPLIT-20260208

> **Status:** open
> **Blocked By:** LOOP-MEDIA-STACK-ARCH-20260208
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

Split the monolithic media-stack (VM 201) into two purpose-built VMs: VM 209 (download-stack) and VM 210 (streaming-stack) on pve (shop R730XD). Separating I/O-heavy download operations from latency-sensitive streaming access patterns improves resource isolation, simplifies maintenance, and enables independent scaling.

---

## Rationale

### Why Split

| Problem | Impact |
|---------|--------|
| SABnzbd saturates disk I/O during downloads | Jellyfin buffering for active streams |
| Radarr/Sonarr import operations spike CPU | Navidrome transcoding stutters |
| Single VM failure takes down everything | No isolation between acquisition and consumption |
| Mixed workload makes resource tuning impossible | Can't optimize for both I/O throughput and low latency |

### Split Strategy

- **Download stack (VM 209):** Write-heavy, bursty I/O, tolerant of latency
- **Streaming stack (VM 210):** Read-heavy, steady I/O, latency-sensitive

---

## Target Architecture

### VM 209: download-stack (shop R730XD)

| Service | Port | Purpose | Status |
|---------|------|---------|--------|
| SABnzbd | 8080 | Usenet downloader | This loop |
| Radarr | 7878 | Movie management | This loop |
| Sonarr | 8989 | TV management | This loop |
| Lidarr | 8686 | Music management | This loop |
| Prowlarr | 9696 | Indexer manager | This loop |
| Tdarr | 8265 | Transcode automation | This loop |
| Huntarr | — | Hunt automation | This loop |
| Recyclarr | — | Config sync for *arr apps | This loop |

### VM 210: streaming-stack (shop R730XD)

| Service | Port | Purpose | Status |
|---------|------|---------|--------|
| Jellyfin | 8096 | Video streaming | This loop |
| Navidrome | 4533 | Music streaming | This loop |
| Bazarr | 6767 | Subtitle management | This loop |
| Jellyseerr | 5055 | Request management | This loop |
| Slskd | 5030 | Soulseek client | This loop |

---

## Phases

| Phase | Scope | Dependency |
|-------|-------|------------|
| P0 | Design container split + NFS mount plan | Blocked by LOOP-MEDIA-STACK-ARCH-20260208 |
| P1 | Provision VM 209 (download-stack) + VM 210 (streaming-stack) | P0 |
| P2 | Migrate download containers to VM 209 | P1 |
| P3 | Migrate streaming containers to VM 210 | P2 |
| P4 | Update NFS mounts + Cloudflare tunnel routes | P3 |
| P5 | Decommission VM 201 (media-stack) | P4 + soak period |
| P6 | Verify + closeout | P5 |

---

## NFS Mount Strategy

Both VMs need access to media storage on the NAS. The split requires careful mount planning.

### Shared NFS Mounts

| Mount | Source (NAS) | VM 209 | VM 210 |
|-------|-------------|--------|--------|
| `/media/movies` | NAS export | Read/Write | Read-only |
| `/media/tv` | NAS export | Read/Write | Read-only |
| `/media/music` | NAS export | Read/Write | Read-only |
| `/downloads` | NAS export | Read/Write | — |

### Key Principle

- Download stack (209): Read/Write to media + downloads
- Streaming stack (210): Read-only to media (never writes)
- Downloads directory: Only mounted on 209

---

## Migration Order

Migration must be sequenced to avoid service gaps:

1. **Prowlarr first** — Indexer manager, no user-facing impact
2. **SABnzbd** — Downloader, can pause queue during migration
3. **Radarr/Sonarr/Lidarr** — Point to new SABnzbd + Prowlarr
4. **Tdarr/Huntarr/Recyclarr** — Support services
5. **Jellyfin** — User-facing, migrate during low-usage window
6. **Navidrome/Bazarr/Jellyseerr/Slskd** — Streaming companions

---

## Cloudflare Tunnel Updates (P4)

Routes that currently point to VM 201 must be updated:

| Hostname | Old Target | New Target |
|----------|-----------|------------|
| jellyfin.ronny.works | VM 201:8096 | VM 210:8096 |
| requests.ronny.works | VM 201:5055 | VM 210:5055 |
| music.ronny.works | VM 201:4533 | VM 210:4533 |

Download services (SABnzbd, *arr apps) route through Caddy with Authentik auth.

---

## Secrets Required

| Secret | Project | Notes |
|--------|---------|-------|
| SABNZBD_API_KEY | media | Existing, move to new VM |
| RADARR_API_KEY | media | Existing |
| SONARR_API_KEY | media | Existing |
| PROWLARR_API_KEY | media | Existing |
| JELLYFIN_API_KEY | media | Existing |

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| VM 209 + 210 provisioned | SSH reachable, Tailscale joined |
| All download services on 209 | SABnzbd queue processing, *arr apps importing |
| All streaming services on 210 | Jellyfin playback working, Navidrome streaming |
| NFS mounts correct | 209 has R/W, 210 has R/O to media |
| Cloudflare tunnel updated | External URLs resolve to new VMs |
| VM 201 decommissioned | Powered off after soak period |
| No cross-VM I/O contention | Streaming smooth during active downloads |

---

## Non-Goals

- Do NOT redesign the *arr app configuration (just migrate as-is)
- Do NOT change NAS export structure (use existing shares)
- Do NOT add new media services in this loop
- Do NOT set up hardware transcoding (separate concern)

---

## Evidence

- LOOP-MEDIA-STACK-ARCH-20260208 (prerequisite — architecture decisions)
- GAP-OP-010: media-stack missing from ssh.targets.yaml (must fix during migration)
- Current VM 201 runs all media services monolithically

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
