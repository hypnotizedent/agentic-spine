---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-17
verification_method: device-identity parity + generated storage authority synthesis
scope: shop-control-plane-summary
---

# SHOP SERVER SSOT

This is the spine-facing summary for the shop rack and shop-managed endpoints.

Authority boundary:
- Canonical identity and network naming live in `docs/governance/DEVICE_IDENTITY_SSOT.md`.
- Detailed shop hardware procedures and operator runbooks live in `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/shop/SHOP_SERVER_SSOT.md`.
- This spine doc keeps agent facts, ripple checks, and shop network parity attached to a real governed surface.
- When generated spine storage surfaces disagree with older workbench prose, the spine bindings/projections win.

## Managed Shop Endpoints

| Class | Device | Canonical IP | Access Model | Notes |
|-------|--------|--------------|--------------|-------|
| Gateway | `udr-shop` | `192.168.1.1` | LAN-only | UniFi Dream Router 6 |
| Switch | `switch-shop` | `192.168.1.2` | LAN-only | Dell N2024P |
| OOB Mgmt | `idrac-shop` | `192.168.1.250` | LAN-only | Shop hypervisor iDRAC |
| Camera NVR | `nvr-shop` | `192.168.1.216` | LAN-only | Hikvision recorder |
| WiFi AP | `ap-shop` | `192.168.1.185` | LAN-only | TP-Link EAP225 |
| Hypervisor SSH | `pve` | `100.96.211.33` | Tailscale | Canonical operator SSH target |
| Tombstone VM | `docker-host` | `192.168.1.200` | Historical identity | Cold restore capsule only; not runtime |
| Automation VM | `automation-stack` | `192.168.1.110` | LAN | n8n / automation workloads |
| Photos VM | `immich` | `192.168.1.203` | LAN | Shop photos VM |
| Core infra VM | `infra-core` | `192.168.1.204` | LAN | DNS/auth/secrets core |
| Observability VM | `observability` | `192.168.1.205` | LAN | Prometheus / Grafana / Loki |
| Dev tools VM | `dev-tools` | `192.168.1.206` | LAN | Gitea and related services |
| AI VM | `ai-consolidation` | `192.168.1.8` | LAN | Qdrant / AI workloads |
| Downloads VM | `download-stack` | `192.168.1.209` | LAN | Rollback-only legacy media write VM |
| Streaming VM | `streaming-stack` | `192.168.1.210` | LAN | Rollback-only legacy media playback VM |
| Finance VM | `finance-stack` | `192.168.1.211` | LAN | Finance services |
| Mint data VM | `mint-data` | `192.168.1.212` | LAN | Mint data plane |
| Mint apps VM | `mint-apps` | `192.168.1.213` | LAN | Mint app plane |
| Communications VM | `communications-stack` | `192.168.1.26` | LAN | Stalwart + mail archiver |

## Canonical Rack Target Model

| Plane | Canonical surface | Boring target |
|-------|-------------------|---------------|
| Substrate | `ops/bindings/hardware.inventory.yaml` | `pve` is the only shop hypervisor. |
| Storage | `ops/bindings/shop.storage.map.yaml` + `ops/bindings/shop.storage.atlas.yaml` + `ops/bindings/shop.media.pressure.authority.yaml` + `ops/bindings/shop.storage.scaffold.contract.yaml` + `ops/bindings/hardware.inventory.yaml` + `ops/bindings/backup.inventory.yaml` | `tank` = hot runtime/app state, `media` = media payload only or phased-out pressure lane, `md1400` = cold backup/archive/staging only. Media pressure truth comes from the client-visible `/media` export, not the host-local child dataset mount view. |
| Runtime | `ops/bindings/vm.lifecycle.yaml` + `docs/governance/STACK_REGISTRY.yaml` | Every kept workload is a named VM/LXC or a container stack inside one; tombstones are not runtime. |
| Network | `docs/governance/DEVICE_IDENTITY_SSOT.md` + `ops/bindings/ssh.targets.yaml` | One LAN identity truth and one Tailscale truth per kept node. |
| Ingress | `ops/bindings/shop.ingress.map.yaml` + `ops/bindings/domain.routing.registry.yaml` | Public services are either intentionally published via Cloudflare or explicitly private-only, and compatibility/ghost routes are explicit. |
| Backup | `ops/bindings/backup.inventory.yaml` + `docs/governance/domains/backup.md` | One backup matrix per runtime unit: VM artifact, app/state supplement, offsite exception, and restore class. |
| Monitoring | `docs/governance/SERVICE_REGISTRY.yaml` + `ops/bindings/services.health.yaml` | Every kept VM gets a baseline of host reachability, critical service health, and capacity visibility. |
| Tombstones | `ops/bindings/docker-host.deprecation.contract.yaml` + `ops/bindings/vm.lifecycle.yaml` | Dead systems carry explicit tombstone status, one restore story, and an expiry/review date. |

## Generated Projections

- Storage authority projection: `ops/bindings/shop.storage.map.yaml`
- Live observed storage atlas: `ops/bindings/shop.storage.atlas.yaml`
- Warm-lane pressure authority: `ops/bindings/shop.media.pressure.authority.yaml`
- Boring storage scaffold contract: `ops/bindings/shop.storage.scaffold.contract.yaml`
- Media boring target doctrine: `docs/governance/MEDIA_STACK_BORING_TARGET.md`
- Media lifecycle contract: `ops/bindings/media.lifecycle.contract.yaml`
- Ingress authority projection: `ops/bindings/shop.ingress.map.yaml`
- Rack scorecard: `docs/reference/generated/SHOP_RACK_SCORECARD.md`
- Storage drift report: `docs/reference/generated/SHOP_STORAGE_ATLAS_DRIFT.md`
- Estate closure scorecard: `docs/reference/generated/ESTATE_BORINGNESS_SCORECARD.md`
- Rebuild commands:
  - `./bin/ops cap run infra.shop.storage.authority.build`
  - `./bin/ops cap run infra.shop.storage.atlas.build`
  - `./bin/ops cap run media.capacity.snapshot.build`
  - `./bin/ops cap run infra.estate.boringness.build`

## Storage Precedence

For live observed shop storage state, agents should read surfaces in this order:

1. `ops/bindings/shop.storage.atlas.yaml`
2. `ops/bindings/shop.media.pressure.authority.yaml`
3. `ops/bindings/shop.storage.map.yaml`
4. `ops/bindings/shop.storage.scaffold.contract.yaml`
5. This summary doc
6. Workbench deep-dive docs

For storage meaning and target boringness, agents should read surfaces in this order:

1. `ops/bindings/shop.storage.map.yaml`
2. `ops/bindings/shop.media.pressure.authority.yaml`
3. `ops/bindings/backup.inventory.yaml`
4. `ops/bindings/infra.storage.placement.policy.yaml`
5. `ops/bindings/shop.storage.scaffold.contract.yaml`
6. `ops/bindings/shop.storage.atlas.yaml`
7. This summary doc
8. Workbench deep-dive docs

This keeps observed reality and target contract separate while preventing older workbench snapshots from outranking newer spine projections.

## Current Boring Baseline

Current lane meanings:

- `tank` is the shop hot runtime plane. `tank/vms` is the default guest runtime disk lane, `tank/docker` is the NFS-backed app-state lane, `tank/immich` is the photo-library lane, and `tank/backups/vzdump/dump` is only the local generation lane before promotion into `md1400`.
- `media` is the warm payload plane. The client-visible `/media` NFS export is the payload truth. `media` is not a backup plane, and it is no longer registered as a Proxmox dir-storage backend.
- `md1400` is the shop cold plane. `md1400/backup-cold` is canonical cold backup truth, `md1400/archive` is the explicit archive namespace for live-share/media-hold/backup-hold content, and `md1400/stage` is temporary landing space.
- In the home-target lifecycle, intentionally kept watched media belongs under `md1400/archive/media-library` as shop cold retention, not as a second live library.

Operationally:

- `tank/backups` answers: "did the backup job run and what is the fresh artifact?"
- `md1400/backup-cold` answers: "what do we restore from?"

Residual storage friction today:

- `media` remains at 95%, so namespace normalization has reduced pressure but has not closed `GAP-OP-1526`.
- `download-stack` still logs zero-free-space import failures even though the NFS mount now shows about `798G` available.
- `/md1400/archive/media-holds` and `/md1400/archive/backup-holds` are now explicit hold lanes, but their contents still need lifecycle review over time.

Accepted storage decision:

- `movies-archive` is a warm runtime-visible media surface. It belongs to the live `/media` lane, not to `md1400` as its steady-state mounted backing.

## Backup Truth Model

The boring backup model is:

- `tank/backups/vzdump/dump` is the generation outbox. It is where fresh Proxmox VM/LXC artifacts land first.
- `md1400/backup-cold/vzdump/pve` is the canonical cold restore lane for VM/LXC recovery.
- `md1400/backup-cold/apps/<domain>` is the canonical cold restore lane for app and domain state.
- `md1400/backup-cold/archive-smb/snapshots` is the canonical protection lane for archive-SMB snapshot manifests.

Interpretation rules:

- A generated backup is not yet the restore truth.
- If the same unit exists in both `tank/backups` and `md1400/backup-cold`, `md1400/backup-cold` wins.
- Pruning `tank/backups` after successful promotion is normal and does not mean backup truth was lost.
- `md1400/backup-cold` is not generic scratch space. Everything under it must map to a governed backup lane.

## VM Storage Truth Model

The boring VM storage model is:

- `/tank/vms` is the default runtime disk truth for kept shop guests that need durable block storage.
- `/tank/docker/<stack>` is the runtime config/state truth for kept NFS-backed shop application stacks; legacy media stacks there are rollback-only, not canonical live media truth.
- `local-lvm` is a system or explicit exception surface, not the default answer for durable guest growth.
- `archive-smb` is only the serving wrapper; the archive payload it exposes is authoritative on `md1400`.

Interpretation rules:

- Ask `/tank/vms` when the question is "where does the kept guest's primary runtime disk belong?"
- Ask `/tank/docker/<stack>` when the question is "where does this NFS-backed app stack keep config/state?"
- Do not treat `local-lvm` as the boring long-term home for growing guest state.
- If a guest serves `md1400` data, the `md1400` dataset remains payload truth even if the guest rootfs is rebuilt.

Current transition exceptions:

- `immich` still has a boot disk on `local-lvm`, but its runtime library truth is `tank/immich`.
- `infra-core`, `observability`, `dev-tools`, `ai-consolidation`, `finance-stack`, and `mint-apps` still carry accepted boot-only posture because their durable state is small.
- `archive-smb` restores its rootfs from `vzdump`, but its live-share payload truth remains on `md1400`.

## Big-Data Truth Model

The boring big-data model is:

- `tank/immich` is the runtime truth for the photo library.
- `/media` is the runtime-visible truth for live media payload.
- `/md1400/archive/live-share` is the runtime truth for archive/live-share datasets.
- `/md1400/archive/media-library` is the cold-retention truth for intentionally kept watched media promoted out of home.
- `/md1400/archive/media-holds` is where residual media holds belong after normalization, if they need to exist at all.

Interpretation rules:

- Immich growth belongs to `tank/immich`, not to the VM boot disk and not to `md1400`.
- Live media payload belongs to `/media` and stays distinct from backup and archive planes.
- Cold retained media promoted from home belongs to `/md1400/archive/media-library` and should be restored on demand rather than mounted as live payload.
- `movies-archive` remains part of the live `/media` lane.
- Archive/live-share data belongs under `/md1400/archive/live-share`, not as loose `md1400` roots.
- `/md1400/archive/media-holds` is an explicit archive-hold surface, not a canonical live-data truth lane.

## Ideal Boring Storage Scaffold

The boring target is:

- `tank` only for hot runtime and local backup generation.
- `media` only for warm runtime-visible payload.
- `md1400` only for cold backup, archive, stage, and tombstone lanes.
- `local-lvm` only for Proxmox system surfaces and explicit temporary exceptions.
- No project- or content-named roots at the top of `md1400`.
- No cross-pool mount overlays where one pool hides another pool's runtime path.

Target tree:

```text
/tank
  /vms
  /docker
  /immich
  /backups/vzdump/dump

/media
  /movies
  /tv
  /music
  /downloads
  /movies-archive

/md1400
  /backup-cold
    /vzdump/pve
    /apps/<domain>
    /archive-smb/snapshots
  /archive
    /backup-holds/tank-backups/<lane>
    /media-library/{movies,tv,music}
    /live-share/mint-legacy
    /live-share/ronny-projects
    /media-holds/<hold>
  /stage/<wave-or-purpose>
  /tombstones/<unit-id>
```

Interpretation rules:

- `tank/backups` is staging, not canonical shop backup truth.
- `tank/vms` is the default durable guest disk lane.
- `tank/docker` is the default NFS-backed app-state lane.
- `tank/immich` is the photo-library lane.
- `md1400/backup-cold` is canonical shop cold restore truth.
- Archive/live-share data should sit under one archive namespace, not as loose `md1400` roots.
- `local-lvm` is a system/exception surface, not the boring answer for durable guest growth.
- `stage` should be empty between waves or contain only owner- and date-scoped subpaths.
- `tombstones` should be review-bound restore holds, never silent leftovers.
- `movies-archive` is now explicitly assigned to the live `/media` lane.
- `md1400` may carry archive or backup copies related to `movies-archive`, but it should not mask the live `/media/movies-archive` runtime path.

## Next Normalization Wave

The next boringness wave should do exactly this:

- keep `/md1400/stage` empty between waves,
- reduce `media` pressure further by working `/media/downloads`,
- fix the app-level zero-free-space/import stall on `download-stack`,
- keep `/media` as the single-lane runtime-visible surface with `movies-archive` on the media pool, and
- leave hardware replacement as a separate later change.

## Drive Change Posture

Current stance: blocked.

New drives do not justify opportunistic reshuffling. Replace hardware only after:

- the boring scaffold above is accepted as the naming contract,
- `/md1400/stage` stays empty between waves,
- archive residue remains under explicit `/md1400/archive/...` lanes, and
- `download-stack` import flow is no longer pinned by the false zero-free-space gate, and
- `GAP-OP-1526` is closed by getting the media lane back below the guard threshold.

## Current Tombstones

| Tombstone | Runtime posture | Cold restore posture | Review date | Notes |
|-----------|-----------------|----------------------|-------------|-------|
| `docker-host` / VM200 | Not runtime. `local-lvm:vm-200-disk-0` was removed from hot storage on `2026-03-12`; do not return this guest to the runtime plane. | Keep exactly one cold restore capsule at `pve:/md1400/backup-cold/vzdump/pve` via `vm-200-docker-host-primary`. Restore only as isolated temporary sandbox identity. | `2026-09-06` | Historical Mint/docker-host duties are now split across `mint-apps`, `mint-data`, `finance-stack`, `observability`, and `communications-stack`. |

## Verification

```bash
./bin/ops cap run network.shop.audit.status
./bin/ops cap run spine.ripple.check -- switch-shop
./bin/ops cap run spine.ripple.check -- communications-stack
```
