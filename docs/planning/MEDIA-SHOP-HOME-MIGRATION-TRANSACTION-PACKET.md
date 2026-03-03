# Media Shop-to-Home Migration Transaction Packet

> Canonical transaction packet for media stack relocation from shop to home.
> Authority: LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303
> Status: planning (not yet executable)
> Closes: GAP-OP-1402

## Prerequisites (all must be true before cutover)

| # | Prerequisite | Gate/Evidence | Status |
|---|-------------|---------------|--------|
| P1 | Home target topology finalized in contract | GAP-OP-1403 | blocked_by_ronny_arch_decision |
| P2 | Path authority contract enforced (4-way parity) | GAP-OP-1404 | open |
| P3 | Status progression contract defined | GAP-OP-1405 | open |
| P4 | Home network throughput validated (NFS/SMB perf) | GAP-OP-1403 | blocked |
| P5 | Home storage capacity confirmed (tank/NFS) | infra.storage.placement.policy.yaml | blocked |
| P6 | Backup posture verified for home target | backup.inventory.yaml | blocked |
| P7 | All disconnect-trace gaps resolved | GAP-OP-1387..1393 | open |
| P8 | Lineage checkpoint reviewed | GAP-OP-1406 | open |

## Preflight Phase

Before any runtime mutation:

1. **Snapshot current state**
   - Radarr: export movie list, root folders, download client config
   - Sonarr: export series list, root folders, download client config
   - Jellyfin: export library configuration, plugin list
   - Jellyseerr: export request state
   - SABnzbd: export server/category config
   - Docker compose files: archive current versions

2. **Health baseline capture**
   - Run `./bin/ops cap run media.status` — all services must be UP
   - Run `./bin/ops cap run verify.pack.run media` — all gates must PASS
   - Record: service count, movie count, series count, library item count

3. **Home-side readiness verification**
   - VM provisioned with correct VMID, hostname, network
   - NFS/SMB mounts tested from home VM to NAS
   - Docker runtime installed and configured
   - Tailscale enrolled with correct access_policy

## Cutover Phase

Single-service-at-a-time migration with verification gates between each:

### Phase 1: Storage + NFS Migration
- Mount home NAS shares to home VM
- Verify read/write access to media paths
- Verify path parity: compose mount, app root, downloader path, library path

### Phase 2: Download Stack Migration (VM 209 services)
- Stop download-stack services on shop VM 209
- Deploy docker compose on home target
- Configure SABnzbd with home paths
- Configure Radarr/Sonarr/Lidarr root folders with home paths
- Start services and verify health URLs

### Phase 3: Streaming Stack Migration (VM 210 services)
- Stop streaming-stack services on shop VM 210
- Deploy docker compose on home target
- Configure Jellyfin libraries with home paths
- Configure Jellyseerr connection to home Radarr/Sonarr
- Start services and verify health URLs

### Phase 4: DNS/Routing Cutover
- Update CF tunnel ingress rules (if applicable)
- Update ssh.targets.yaml with new host/IP
- Update services.health.yaml endpoints
- Update docker.compose.targets.yaml

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
| Download test | Trigger test download and verify import chain | End-to-end success |
| Playback test | Play a title via Jellyfin | Successful playback |

## SSOT Updates Required

Per infra.relocation.plan.yaml convention:
- `docs/governance/SERVICE_REGISTRY.yaml`
- `docs/governance/STACK_REGISTRY.yaml`
- `docs/governance/DEVICE_IDENTITY_SSOT.md`
- `ops/bindings/services.health.yaml`
- `ops/bindings/ssh.targets.yaml`
- `ops/bindings/backup.inventory.yaml`
- `ops/bindings/docker.compose.targets.yaml`
- `ops/bindings/media.services.yaml`
- `ops/bindings/infra.relocation.plan.yaml` (new active_relocation entry)

## Execution Mode

- **Recommended**: `orchestrator_subagents` (per planning.horizon.contract.yaml v1.3)
- **Requires**: Ronny on-site at home for physical provisioning and verification
- **Terminal**: Single-writer (no parallel mutating terminals during cutover)
