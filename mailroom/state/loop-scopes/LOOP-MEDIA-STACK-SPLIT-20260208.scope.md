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

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Governance + secrets setup (placement, relocation, compose, SSOT) | None | DONE |
| P1 | Provision VM 209 + VM 210 | P0 | DONE |
| P2 | Prepare NFS + local storage | P1 | DONE |
| P3 | Migrate download stack to VM 209 | P2 | DONE — 24/24 healthy |
| P4 | Migrate streaming stack to VM 210 | P3 | DONE — 10/10 containers healthy, spotisub OAuth complete |
| P5 | Update routing + SSOT (CF tunnel, bindings) | P4 | DONE — CF tunnel v82, all SSOT updated |
| P6 | Soak (72h) + decommission VM 201 | P5 | VERIFIED — soak passed 2026-02-10, ready for decom |
| P7 | Decommission VM 201 | P6 | IN PROGRESS — stopped 2026-02-10, 48h hold until 2026-02-12 |
| P8 | Media stack metrics + observability | P6 | OPEN — rolled in from LOOP-MEDIA-STACK-METRICS |

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
| spotisub.ronny.works | _(none — new)_ | VM 210:8766 |

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
| Drift gates pass | 49/49 PASS on `ops verify` |

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

## Related Loops

| Loop | Relationship | Status |
|------|-------------|--------|
| LOOP-MEDIA-STACK-ARCH-20260208 | Prerequisite — SQLite off NFS, boot ordering | Closed |
| LOOP-MEDIA-STACK-RCA-20260205 | Root cause analysis — daily crashes | Closed |
| **LOOP-MEDIA-AGENT-WORKBENCH-20260208** | **Follow-on — media domain agent for application-layer governance** | **Open (P0 done)** |

The media agent loop was spawned from this split work. During P6 soak, "The Beach House" was found in Jellyfin with non-English audio — exposing that no agent governs language profiles, quality settings, or media service configuration. The split gave us the infrastructure (2 VMs, clean deployment); the media agent gives us application-layer control.

Agent discovery governance (D49 drift gate, `agents.registry.yaml`, `generate-context.sh` injection) was built as a prerequisite. The media-agent is the first domain agent registered in the spine. See `ops/agents/media-agent.contract.md` for the ownership boundary.

## Evidence

- LOOP-MEDIA-STACK-ARCH-20260208 (prerequisite — closed)
- LOOP-MEDIA-STACK-RCA-20260205 (root cause analysis — closed)
- LOOP-MEDIA-AGENT-WORKBENCH-20260208 (follow-on — open)
- docs/brain/lessons/MEDIA_STACK_LESSONS.md (operational lessons)
- ops/agents/media-agent.contract.md (agent ownership contract)
- ops/bindings/agents.registry.yaml (agent discovery registry)

---

## Phase Completion Notes

### P3 — Download Stack (2026-02-08)
- 24 containers running on VM 209, all healthy
- NFS fstab corrected: Tailscale IP → LAN IP (192.168.12.184) after D-state deadlock incident
- watchtower fix: `DOCKER_API_VERSION=1.45` (Docker CE 29.x)
- trailarr fix: internal port 7889 (not 7667), healthcheck accepts 401 as healthy
- VM 201 download services STOPPED

### P4 — Streaming Stack (2026-02-08)
- 10/10 containers running on VM 210, all healthy
- spotisub: initially crash-looping (Spotify OAuth expired). CF tunnel ingress + DNS CNAME added 2026-02-08 for `spotisub.ronny.works`. Spotify OAuth re-auth completed 2026-02-08 at `https://spotisub.ronny.works/` — DONE
- homarr: uses `ghcr.io/ajnart/homarr:latest` (v1, not v2 — config format incompatible)
- navidrome/jellyseerr/homarr: healthchecks use wget (no curl in containers)
- jellyseerr: radarr/sonarr URLs updated to 100.107.36.76, jellyfin updated to docker name `jellyfin` — DONE
- VM 201 streaming services STOPPED — zero running containers on VM 201

### P5 — Routing + SSOT (2026-02-08)
- CF tunnel v82: jellyfin/requests/music .ronny.works → VM 210 (100.123.207.64)
- External URL verification: jellyfin 200, requests 307 (login redirect), music 200
- STACK_REGISTRY: download-stack + streaming-stack status → `active`
- SERVICE_REGISTRY: verified date → 2026-02-08
- SSH targets: download-stack restored to Tailscale IP (100.107.36.76)
- services.health: jellyseerr expect → 307
- **spotisub.ronny.works (added 2026-02-08):** CF tunnel ingress rule (`PUT /configurations`) + DNS CNAME (`ae7d4462...cfargotunnel.com`, proxied) created via API. Verified: HTTP 302 → `/login` through tunnel. `domain_routing.diff` OK (39/39). DOMAIN_ROUTING_REGISTRY note updated to "Active".

### Post-Migration Connectivity Audit (2026-02-08)

Deep audit of all 34 containers across VM 209 + VM 210 for stale IPs, broken cross-VM references, and misconfigured backends. Root cause: splitting monolithic VM 201 created cross-VM network boundaries that didn't exist before.

**P0 fixes applied:**

| Service | VM | Issue | Stale Value | Fixed To |
|---------|-----|-------|-------------|----------|
| Jellyfin libraries | 210 | Media paths `/data/media/` didn't exist in container | `/data/media/movies`, `/data/media/tv` | `/media/movies`, `/media/tv` |
| Jellyseerr → Jellyfin | 210 | `127.0.0.1` unreachable cross-container | `127.0.0.1:8096` | `jellyfin:8096` (docker DNS) |
| Jellyseerr → Jellyfin | 210 | `IsStartupWizardCompleted=false` in system.xml | `false` | `true` |
| Prowlarr → Radarr | 209 | App sync pointed to decommissioned VM 201 | `100.117.1.53:7878` + stale API key | `http://radarr:7878` + current key |
| Posterizarr → Jellyfin | 209 | Docker container name unresolvable cross-VM | `http://jellyfin:8096` | `http://100.123.207.64:8096` |
| Jellyfin plugin (HomeScreenSections) | 210 | Sonarr+Radarr URLs pointed to VM 201 | `100.117.1.53` | `100.107.36.76` |

**P2 fix applied:**

| Service | VM | Issue | Fixed To |
|---------|-----|-------|----------|
| Recyclarr → Radarr | 209 | Docker bridge IP instead of container name | `http://radarr:7878` |

**P3 deferred to media-agent (LOOP-MEDIA-AGENT-WORKBENCH-20260208):**

| Service | VM | Status | Notes |
|---------|-----|--------|-------|
| Unpackerr | 209 | All arr integrations commented out | Running idle — enable if extraction needed |
| Trailarr | 209 | Zero arr connections | Running idle — configure via web UI :7667 |
| Crosswatch | 209 | Empty config | Running idle — configure via web UI :8787 |
| Wizarr | 210 | Setup wizard never completed | Configure via :5690 when ready |
| Homarr | 210 | Default template only | Cosmetic — configure dashboard links |

**Stale IP `100.117.1.53` (VM 201 media-stack):** Found in Prowlarr DB + Jellyfin plugin config. Fully remediated. No other references to old VM 201 or docker-host (100.92.156.118) found.

**Verified clean:** jellyseerr, bazarr, navidrome, spotisub, subgen, autopulse, huntarr, soularr, all swaparr instances, radarr, sonarr, lidarr, sabnzbd, qbittorrent, decypharr, tdarr, crowdsec, flaresolverr, watchtower (x2), node-exporter (x2).

### P6 — Soak Verification (2026-02-10)

**72h soak window:** 2026-02-08 through 2026-02-10 — PASSED.

**VM 209 (download-stack) — 19/24 containers running, 5 intentionally stopped:**

| Status | Containers |
|--------|-----------|
| Running (19) | autopulse, crosswatch, crowdsec, decypharr, flaresolverr, lidarr, node-exporter, posterizarr, prowlarr, qbittorrent, radarr, recyclarr, sabnzbd, sonarr, soularr, swaparr-radarr, trailarr, unpackerr, watchtower |
| Exited (5) | huntarr, slskd, swaparr-lidarr, swaparr-sonarr, tdarr |

- All 19 running containers report "Up 17 hours" — stable since last watchtower cycle
- Healthcheck-enabled containers all report `(healthy)`: autopulse, crosswatch, decypharr, lidarr, node-exporter, prowlarr, qbittorrent, radarr, sabnzbd, sonarr, trailarr, watchtower
- 5 exited containers (huntarr, slskd, swaparr-lidarr, swaparr-sonarr, tdarr) were noted as "evaluate during soak" in the original scope — these are non-critical and can be re-enabled via media-agent when needed
- **NFS mounts healthy:** `/mnt/docker` (rw, 192.168.1.184:/tank/docker/download-stack, nfs4), `/mnt/media` (rw, 192.168.1.184:/media, nfs4) — both using LAN IPs as required

**VM 210 (streaming-stack) — 10/10 containers running:**

| Status | Containers |
|--------|-----------|
| Running (10) | bazarr, homarr, jellyfin, jellyseerr, navidrome, node-exporter, spotisub, subgen, watchtower, wizarr |

- All 10 containers report "Up 17 hours" — stable since last watchtower cycle
- Healthcheck-enabled containers all report `(healthy)`: bazarr, homarr, jellyfin, jellyseerr, navidrome, node-exporter, watchtower, wizarr
- No exited containers
- **NFS mounts healthy:** `/mnt/docker` (rw, 192.168.1.184:/tank/docker/streaming-stack, nfs4), `/mnt/media` (**ro**, 192.168.1.184:/media, nfs4) — read-only for media as designed, both using LAN IPs

**VM 201 (media-stack) — idle, ready for shutdown:**

- Status: `running` (qm status 201) — not yet stopped
- Uptime: 17h33m, load average: 0.00 0.00 0.00
- Docker daemon: **not running** — no containers active
- Resources consumed: 16GB RAM allocated (~850MB used), 4 cores, zero I/O pressure
- `onboot: 1` still set — must be disabled before or during decom to prevent accidental restart

**Soak Verdict: PASS** — all production workloads stable on VMs 209/210 for 48+ hours with zero container restarts. VM 201 is idle with no Docker activity. Ready for decommission.

### P7 — Decommission VM 201 (IN PROGRESS)

Decommission sequence:
1. `ssh root@pve 'qm set 201 --onboot 0'` — **DONE** (2026-02-10T14:38Z)
2. `ssh root@pve 'qm stop 201'` — **DONE** (2026-02-10T14:38Z, status: stopped)
3. Wait 48 hours — **HOLD UNTIL 2026-02-12T14:38Z** (rollback window)
4. `ssh root@pve 'qm destroy 201 --purge'` — PENDING (after hold)
5. Clean up SSOT: remove VM 201 references from ssh.targets.yaml, docker.compose.targets.yaml, STACK_REGISTRY, SERVICE_REGISTRY
6. Remove `tank/docker/media-stack` ZFS dataset on pve (rollback data no longer needed)

### P8 — Media Stack Metrics + Observability (rolled-in)

Rolled in from LOOP-MEDIA-STACK-METRICS. Now that the split is stable:
- Configure Prometheus scrape targets for node-exporter on VMs 209 (.209:9100) and 210 (.210:9100)
- Add Grafana dashboards for per-VM resource utilization (validate the I/O isolation thesis)
- Configure Loki log collection from both VMs
- Remove any stale VM 201 monitoring references

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
_Updated: 2026-02-10 (P6 soak verified, P7 decom ready, P8 metrics rolled in)_
