# LOOP-MEDIA-STACK-SPLIT-20260208

> **Status:** open
> **Blocked By:** _(none — LOOP-MEDIA-STACK-ARCH-20260208 closed)_
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

Split the monolithic media-stack (VM 201) into two purpose-built VMs: VM 209 (download-stack) and VM 210 (streaming-stack) on pve (shop R730XD). Separating I/O-heavy download operations from latency-sensitive streaming access patterns improves resource isolation, simplifies maintenance, and enables independent scaling.

**Also in scope:** Migrate plaintext .env secrets to Infisical.

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

### VM 209: download-stack (21 containers)

| Category | Services |
|----------|----------|
| Core | sabnzbd, qbittorrent, unpackerr |
| Arr stack | radarr, sonarr, lidarr, prowlarr, recyclarr |
| Arr support | flaresolverr, soularr, swaparr-radarr, swaparr-sonarr, swaparr-lidarr |
| Media support | trailarr, posterizarr, decypharr, huntarr, tdarr |
| Cross-VM | autopulse, crosswatch (call Jellyfin API on VM 210 via Tailscale IP) |
| Security | crowdsec |
| Infra | watchtower, node-exporter |

### VM 210: streaming-stack (10 containers + infra)

| Category | Services |
|----------|----------|
| Core | jellyfin, navidrome, jellyseerr |
| Support | bazarr, wizarr, spotisub, subgen, homarr |
| Infra | watchtower, node-exporter |

### Re-enabled on split (currently stopped — quick-wins)

| Service | Target VM | Notes |
|---------|-----------|-------|
| sabnzbd | VM 209 | I/O isolated from streaming now |
| qbittorrent | VM 209 | I/O isolated from streaming now |
| tdarr | VM 209 | Evaluate during soak — may keep stopped |
| huntarr | VM 209 | Evaluate during soak — may keep stopped |
| slskd | VM 209 | soularr dependency |

---

## NFS Mount Strategy

| VM | Mount | NFS Source (pve) | Mode | Purpose |
|----|-------|------------------|------|---------|
| 209 | `/mnt/docker` | `tank/docker/download-stack` | rw | Container configs |
| 209 | `/mnt/media` | `/media` | rw | Downloads + arr imports |
| 210 | `/mnt/docker` | `tank/docker/streaming-stack` | rw | Container configs |
| 210 | `/mnt/media` | `/media` | **ro** | Streaming reads only |

New ZFS datasets `tank/docker/download-stack` and `tank/docker/streaming-stack` created on pve. Original `tank/docker/media-stack` preserved as rollback until decommission.

---

## Secrets Migration (Infisical)

**Current:** All in plaintext `.env` on VM 201.

**Target structure in Infisical** (`/spine/vm-infra/media-stack/`):

| Path | Keys |
|------|------|
| `/download` | RADARR_API_KEY, SONARR_API_KEY, LIDARR_API_KEY, AUTOPULSE_PASSWORD, REAL_DEBRID_API_KEY |
| `/streaming` | JELLYFIN_API_KEY, NAVIDROME_USER, NAVIDROME_PASSWORD, SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET, LASTFM_API_KEY, LASTFM_SECRET |

Compose uses `infisical run -- docker compose up -d` or generates `.env` via systemd ExecStartPre hook.

---

## Phases

| Phase | Scope | Dependency |
|-------|-------|------------|
| P0 | Governance + secrets setup (placement, relocation, compose, SSOT) | None |
| P1 | Provision VM 209 + VM 210 | P0 |
| P2 | Prepare NFS + local storage | P1 |
| P3 | Migrate download stack to VM 209 | P2 |
| P4 | Migrate streaming stack to VM 210 | P3 |
| P5 | Update routing + SSOT (CF tunnel, bindings) | P4 |
| P6 | Soak (72h) + decommission VM 201 | P5 |

---

## Migration Order

### Phase 3 — Download Stack (VM 209)

prowlarr → flaresolverr → recyclarr → sabnzbd → qbittorrent → unpackerr → radarr → sonarr → lidarr → support services → tdarr/huntarr (evaluate)

**Per-service pattern:**
```
Stop on VM 201 → verify data on VM 209 NFS → compose up on VM 209 → healthcheck → API verify
```

### Phase 4 — Streaming Stack (VM 210)

bazarr → wizarr → spotisub → subgen → navidrome → jellyseerr → jellyfin → homarr

**Jellyfin migration (~15 min downtime):**
```
Stop on 201 → verify data on 210 → compose up → healthcheck → test playback
```

---

## Cloudflare Tunnel Updates (Phase 5)

| Hostname | Old Target | New Target |
|----------|-----------|------------|
| jellyfin.ronny.works | VM 201:8096 | VM 210:8096 |
| requests.ronny.works | VM 201:5055 | VM 210:5055 |
| music.ronny.works | VM 201:4533 | VM 210:4533 |

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| VM 209 + 210 provisioned | SSH reachable, Tailscale joined |
| All download services on 209 | SABnzbd queue processing, *arr apps importing |
| All streaming services on 210 | Jellyfin playback working, Navidrome streaming |
| NFS mounts correct | 209 has R/W, 210 has R/O to media |
| Cloudflare tunnel updated | External URLs resolve to new VMs |
| Secrets in Infisical | No plaintext .env on new VMs |
| VM 201 decommissioned | Powered off after 72h soak |
| No cross-VM I/O contention | Streaming smooth during active downloads |
| Drift gates pass | 47/47 PASS on `ops verify` |

---

## Non-Goals

- Do NOT redesign the *arr app configuration (just migrate as-is)
- Do NOT change NAS export structure (use existing shares)
- Do NOT add new media services in this loop
- Do NOT set up hardware transcoding (separate concern)

---

## Pre-existing Gaps (non-blocking)

| Gap | Description | Impact |
|-----|-------------|--------|
| GAP-OP-025 | media-stack SSH user fix | Affects status tooling, not provisioning |
| GAP-OP-026 | docker.compose.status doesn't resolve via ssh.targets.yaml | Monitoring only |
| GAP-OP-027 | backup.status uses SSH aliases instead of bindings | Monitoring only |
| GAP-OP-028 | secrets scripts fail behind Authentik forward auth | Use internal URL |

---

## Evidence

- LOOP-MEDIA-STACK-ARCH-20260208 (prerequisite — closed)
- LOOP-MEDIA-STACK-RCA-20260205 (root cause analysis — closed)
- docs/brain/lessons/MEDIA_STACK_LESSONS.md (operational lessons)

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
_Updated: 2026-02-08 (plan alignment — unblocked, refined container lists)_
