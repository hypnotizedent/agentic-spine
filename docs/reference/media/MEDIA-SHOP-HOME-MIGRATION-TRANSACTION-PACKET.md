# Media Shop-to-Home Migration Transaction Packet

> Canonical transaction packet for media stack relocation from shop to home.
> Authority: LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303
> Status: active staged cutover
> Closes: GAP-OP-1402
> Current execution state (2026-03-17): Phases 1-5 are live on `media-home`, and all active
> media services now run from the single compose root `/srv/appdata/compose/media-stack`.
> Shop write-lane and streaming-stack services remain rollback-only, and VM 106 now has a
> canonical Synology restore artifact: `vzdump-qemu-106-2026_03_17-15_09_24.vma.zst`.

## Prerequisites (all must be true before cutover)

| # | Prerequisite | Gate/Evidence | Status |
|---|-------------|---------------|--------|
| P1 | Home target topology finalized in contract | ops/bindings/home.media.target.contract.yaml + ops/bindings/home.media.readiness.baseline.yaml | pass |
| P1b | Media lifecycle contract finalized | ops/bindings/media.lifecycle.contract.yaml | pass |
| P1a | Service-by-service execution parity matrix exists | ops/bindings/home.media.execution.parity.matrix.yaml | pass |
| P2 | Path authority contract enforced (4-way parity) | GAP-OP-1404 | pass (runtime verifier live; residual drift tracked separately) |
| P3 | Status progression contract defined | GAP-OP-1405 | pass (runtime verifier live; residual drift tracked separately) |
| P4 | Home network throughput validated (NFS/SMB perf) | ops/bindings/home.media.readiness.baseline.yaml | pass |
| P5 | Home storage capacity confirmed (tank/NFS) | ops/bindings/home.media.readiness.baseline.yaml | pass |
| P6 | Backup posture verified for home target | ops/bindings/home.media.readiness.baseline.yaml | in_progress (VM 106 enrolled in backup-home-p0-daily; first artifact pending) |
| P7 | All disconnect-trace gaps resolved | GAP-OP-1387..1393 | open |
| P8 | Lineage checkpoint reviewed | GAP-OP-1406 | pass |

## Preflight Phase

Before any runtime mutation:

1. **Snapshot current state**
   - Radarr: export movie list, root folders, download client config
   - Sonarr: export series list, root folders, download client config
   - Lidarr: export artist list, root folders, download client config
   - qBittorrent: export categories, save paths, connection settings
   - Jellyfin: export library configuration, plugin list
   - Navidrome: export library/indexing config
   - Jellyseerr: export request state
   - SABnzbd: export server/category config
   - slskd/Soularr: export music pipeline config
   - Homarr/Wizarr/Spotisub/Subgen/Bazarr: export kept user-surface config
   - Helper lane: capture config posture for Recyclarr, Unpackerr, Flaresolverr, CrowdSec, Trailarr, Posterizarr, Autopulse, Crosswatch, Decypharr, Watchtower, node-exporter
   - media-agent + MCPJungle: archive endpoint config and tool/server definitions
   - Secrets posture: record media namespaces and cross-stack consumers
   - Docker compose files: archive current versions

2. **Health baseline capture**
   - Run `./bin/ops cap run media.status` — all services must be UP
   - Run `./bin/ops cap run verify.pack.run media` — all gates must PASS
   - Record: service count, movie count, series count, library item count

3. **Home-side readiness verification**
   - Target matches `ops/bindings/home.media.target.contract.yaml`
   - Lifecycle matches `ops/bindings/media.lifecycle.contract.yaml`
   - Service sequencing matches `ops/bindings/home.media.execution.parity.matrix.yaml`
   - VM provisioned with correct VMID, hostname, network
   - `/mnt/media` exists on proxmox-home and mounts `synology918:/volume1/media-staging`
   - NFS/SMB mounts tested from home VM to NAS
   - Docker runtime installed and configured
   - Tailscale enrolled with correct access_policy

## Cutover Phase

Single-service-at-a-time migration with verification gates between each:

### Phase 1: Storage + NFS Migration
- Provision Synology runtime share `/volume1/media-staging` plus hold share `/volume1/media-holds`
- Mount `/volume1/media-staging` to proxmox-home at `/mnt/media`
- Mount the same runtime share inside the home media VM as `/srv/media`
- Verify read/write access to media paths
- Verify path parity: compose mount, app root, downloader path, library path

### Phase 2: Core Automation and Download Lane
- Stop download-stack services on shop VM 209
- Deploy unified home compose on `media-home`
- Configure SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr, Lidarr, Recyclarr, Unpackerr, and arr-native-search with home paths
- Bring up gluetun + slskd + Soularr if the music lane is in scope for day 1
- Start must-carry services and verify health URLs
- Current staged result (2026-03-17): `sabnzbd`, `qbittorrent`, `prowlarr`, `radarr`, and `sonarr` are live on `media-home` from `/srv/appdata/compose/media-stack` with local state at `/srv/appdata/opt-appdata`.

### Phase 3: Playback, Requests, and Music Consumption
- Stop streaming-stack services on shop VM 210
- Bring up Jellyfin, Jellyseerr, Bazarr, and Navidrome on `media-home`
- Configure Jellyfin libraries with home paths
- Configure Jellyseerr connections to home Radarr/Sonarr/Lidarr
- Start retained user-facing services and verify health URLs
- Current staged result (2026-03-17): `bazarr`, `homarr`, `jellyfin`, `jellyseerr`, `navidrome`, `node-exporter`, `spotisub`, `subgen`, `watchtower`, and `wizarr` are live on `media-home` from `/srv/appdata/compose/media-stack`; shop `streaming-stack` services are stopped and `Movies Archive` is no longer part of the home Jellyfin library set.

### Phase 4: Retained Helper and Experience Surfaces
- Bring up all explicitly kept end-user surfaces and helper services on `media-home`
- Verify Homarr, Wizarr, Spotisub, Subgen, Trailarr, Posterizarr, Autopulse, Crosswatch, Decypharr, Watchtower, and node-exporter on the unified runtime
- Verify they do not reintroduce split-era path or API drift
- Current staged result (2026-03-17): `lidarr`, `unpackerr`, `recyclarr`, `flaresolverr`, `gluetun`, `slskd`, `soularr`, `arr-native-search`, `trailarr`, `posterizarr`, `decypharr`, `autopulse`, `crosswatch`, and `crowdsec` are live on `media-home` from `/srv/appdata/compose/media-stack`; the corresponding shop `download-stack` helper services are stopped.

### Phase 5: DNS, Agent, and Control-Plane Cutover
- Update CF tunnel ingress rules (if applicable)
- Update ssh.targets.yaml with new host/IP
- Update services.health.yaml endpoints
- Update docker.compose.targets.yaml
- Update agents.registry.yaml media-agent endpoints
- Regenerate routing.dispatch.yaml and terminal.worker.catalog.yaml
- Update MCPJungle media-stack server URLs
- Update secrets namespace policy and remove split-runtime ambiguity
- Current staged result (2026-03-17): `media.services.yaml`, `services.health.yaml`, `docker.compose.targets.yaml`, and the home-media SSOT surfaces now resolve `media-home` and `/srv/appdata/compose/media-stack` as the canonical runtime; shop `download-stack` and `streaming-stack` remain rollback-only.

## Rollback Branch

At any phase, rollback by:
1. Stop home services
2. Restart shop services (if still provisioned)
3. Revert DNS/routing changes
4. Verify health baseline matches pre-cutover snapshot

**Rollback window**: 24 hours (per infra.relocation.plan.yaml convention)
**Rollback constraint**: Shop VMs must remain provisioned until post-cutover verification passes

## Post-Cutover Verification Matrix

| Check | Command/Method | Pass Criteria |
|-------|---------------|---------------|
| Service health | `./bin/ops cap run media.status` | All services UP |
| Media gates | `./bin/ops cap run verify.pack.run media` | All gates PASS |
| Movie count parity | Radarr API movie count | Matches pre-cutover |
| Series count parity | Sonarr API series count | Matches pre-cutover |
| Library scan | Jellyfin library item count | Matches pre-cutover |
| Request state | Jellyseerr request count | Matches pre-cutover |
| Path authority | All 4-way path tuples match contract | 0 mismatches |
| Service classification | Every current service accounted for | 0 unclassified active services |
| Download test | Trigger test download and verify import chain | End-to-end success |
| Playback test | Play a title via Jellyfin | Successful playback |
| Agent parity | `media-agent` + `DOMAIN-MEDIA-01` resolve home endpoints only | Healthy and current |

## SSOT Updates Required

Per infra.relocation.plan.yaml convention:
- `docs/governance/SERVICE_REGISTRY.yaml`
- `docs/governance/STACK_REGISTRY.yaml`
- `docs/governance/DEVICE_IDENTITY_SSOT.md`
- `ops/bindings/agents.registry.yaml`
- `ops/bindings/home.media.execution.parity.matrix.yaml`
- `ops/bindings/services.health.yaml`
- `ops/bindings/media.path.authority.contract.yaml`
- `ops/bindings/media.e2e.verification.spec.yaml`
- `ops/bindings/ssh.targets.yaml`
- `ops/bindings/backup.inventory.yaml`
- `ops/bindings/docker.compose.targets.yaml`
- `ops/bindings/media.services.yaml`
- `ops/bindings/secrets.namespace.policy.yaml`
- `ops/bindings/infra.relocation.plan.yaml` (new active_relocation entry)

## Execution Mode

- **Recommended**: `orchestrator_subagents` (per planning.horizon.contract.yaml v1.3)
- **Requires**: Ronny on-site at home for physical provisioning and verification
- **Terminal**: Single-writer (no parallel mutating terminals during cutover)
