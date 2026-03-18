---
status: proposed
owner: "@ronny"
last_verified: 2026-03-17
scope: media-stack-boring-target
---

# MEDIA STACK BORING TARGET

This document defines the most boring target state for the shop media stack.

The goal is not "more capable". The goal is:

- one obvious runtime shape,
- one obvious storage truth per class of data,
- one obvious restore story,
- one obvious operator path for normal maintenance, and
- no hidden cross-VM or cross-mount behavior that agents have to rediscover.

## Preferred Destination

If the intended long-term destination is home, the boring target is:

- one canonical `media-stack` VM on `proxmox-home` (Beelink),
- one canonical payload share on `synology918`,
- one canonical mount path inside the VM, and
- shop media VMs kept only as migration/rollback surfaces until cutover passes.

This means the final boring target is not "merge everything back on the shop rack."
It is "arrive at one clean media appliance on the home site."

Exact home target contract:

- `ops/bindings/home.media.target.contract.yaml`
- `ops/bindings/media.lifecycle.contract.yaml`
- `ops/bindings/media.data.lifecycle.execution.yaml`

## Recommended End State

The most boring target is a single canonical `media-stack` VM that owns the full
media platform, not just the eight obvious apps.

That means the target must explicitly account for the current 32 service
instances and the media control plane, then classify them as:

- must-carry runtime services,
- retained end-user surfaces,
- kept helpers, or
- parked-by-default services.

For the home-target variant, the canonical day-1 platform includes:

- download and indexing: `SABnzbd`, `qBittorrent`, `Prowlarr`
- library automation: `Radarr`, `Sonarr`, `Lidarr`, `Unpackerr`, `Recyclarr`, `arr-native-search`
- music lane: `gluetun`, `slskd`, `Soularr`, `Navidrome`
- playback and requests: `Jellyfin`, `Jellyseerr`, `Bazarr`
- minimal platform sidecars: `CrowdSec`, `Flaresolverr`, one `Watchtower`, one `node-exporter`

Kept in the boring target by explicit decision:

- `Homarr`
- `Wizarr`
- `Spotisub`
- `Subgen`
- `Autopulse`
- `Crosswatch`
- `Posterizarr`
- `Decypharr`
- `Trailarr`

`Watchtower` and `node-exporter` also stay in the target as normalized
single-instance platform sidecars.

Parked or excluded by default in the boring target:

- `Tdarr`
- `Huntarr`
- `Swaparr`

This is simpler than keeping separate `download-stack` and `streaming-stack` VMs because it removes:

- duplicate API relationships across VMs,
- duplicate mount logic,
- duplicate health/debug surfaces,
- duplicate app ownership questions, and
- duplicated request frontends such as `Jellyseerr`.

It also removes split-era hidden dependencies that are easy to forget during
migration:

- split media-agent endpoint wiring,
- split MCPJungle media-stack URLs,
- split Infisical namespaces for media secrets, and
- duplicated infra sidecars that exist only because there are two VMs today.

Boring does not mean stripping the media estate down to the smallest possible
feature set. It means every kept service is intentional, classified, path-stable,
backup-aware, and visible to agents in one contract.

For the home-target variant, that same principle becomes:

- `proxmox-home` runs one Ubuntu media VM,
- `synology918` serves media payload storage,
- the media VM keeps app state on its local VM disk,
- the VM mounts the Synology media share at one canonical path.

## Boring Truth Table

| Class | Canonical truth | Why |
|-------|-----------------|-----|
| Media payload | `synology918:/volume1/<media-share>` mounted into the media VM as `/srv/media` | One visible library/download tree for all media content |
| Media app state | local VM disk mounted at `/srv/appdata` | SQLite-based apps should not keep active DBs on NFS |
| Media VM restore truth | Proxmox VM backup on home backup lane | One restore lane for system + app state |
| Archive / review holds | governed archive lane on Synology or separate explicit hold path | Explicit non-runtime parking area |
| Cold retained media | `/md1400/archive/media-library` | Intentional cold keepers live on shop and return to home only on demand |

## Lifecycle Contract

The boring lifecycle is:

1. request something because you actually want to watch it
2. download it to home
3. watch it from home
4. decide: delete or keep
5. if kept, promote it to shop cold storage
6. if wanted again later, restore it intentionally

The governing rule is:

- home is the hot consumption plane
- shop is the cold retention plane
- there is no endless sync between them
- cold retained media is not mounted as a second live home library by default
- when in doubt, delete; cold retention requires an affirmative keep decision

## Canonical Runtime Layout

Inside the canonical `media-stack` VM:

```text
/srv
  /appdata
    /compose
    /qbittorrent
    /prowlarr
    /radarr
    /sonarr
    /lidarr
    /bazarr
    /jellyseerr
    /jellyfin
    /backups

  /media
    /downloads
      /incomplete
      /complete
        /movies
        /tv
        /music
    /movies
    /tv
    /music
```

Rules:

- `/srv/appdata` is local block storage inside the VM, not NFS.
- `/srv/media` is the only live media mount.
- `/srv/media` is a hot-home library, not a permanent cold archive.
- Every media app uses the same UID/GID.
- Every app sees the same path prefixes.
- No app uses alternate host-only mount names.
- No duplicate public request service exists.
- The boring target must preserve every currently active media function unless it
  is explicitly classified as parked or intentionally retired in
  `ops/bindings/home.media.target.contract.yaml`.
- Intentionally kept watched media should leave the hot-home library and land in the shop cold lane.

## Canonical Container Mount Shape

The boring mount shape inside containers is:

- `qBittorrent`
  - `/config` -> `/srv/appdata/qbittorrent`
  - `/data` -> `/srv/media`
- `Radarr`
  - `/config` -> `/srv/appdata/radarr`
  - `/data` -> `/srv/media`
- `Sonarr`
  - `/config` -> `/srv/appdata/sonarr`
  - `/data` -> `/srv/media`
- `Lidarr`
  - `/config` -> `/srv/appdata/lidarr`
  - `/data` -> `/srv/media`
- `Bazarr`
  - `/config` -> `/srv/appdata/bazarr`
  - `/data` -> `/srv/media`
- `Jellyseerr`
  - `/config` -> `/srv/appdata/jellyseerr`
- `Jellyfin`
  - `/config` -> `/srv/appdata/jellyfin`
  - `/cache` -> `/srv/appdata/jellyfin-cache`
  - `/media` -> `/srv/media`
- `Prowlarr`
  - `/config` -> `/srv/appdata/prowlarr`

Important consequence:

- `downloads`, `movies`, `tv`, and `music` all live under the same mounted media tree, so *arr import paths are boring and consistent.

## Public / Private Surface Target

Public surfaces should be minimal:

- public: `jellyfin`
- public: `jellyseerr` if remote requests are desired

Authenticated private remote surfaces may exist if they are intentionally kept:

- `navidrome`
- `homarr`
- `wizarr`
- `spotisub`

Everything else should be private-only:

- `qBittorrent`
- `Prowlarr`
- `Radarr`
- `Sonarr`
- `Lidarr`
- `Bazarr`
- `SABnzbd`
- `slskd`
- `Soularr`
- `Recyclarr`
- `Unpackerr`
- `Flaresolverr`
- `CrowdSec`

This makes the media stack passive and lowers debugging/security overhead.

## Backup Target

The boring backup model for media is:

- VM artifact backup via the canonical site Proxmox backup lane
- if the final site is home, the canonical VM restore lane is Synology-backed Proxmox dump storage
- if a separate app-state export is kept, it is convenience evidence only unless explicitly declared as restore truth
- no claim that `media` payload is "backup"
- any exceptional retained copy belongs under an explicit archive/hold lane, not the live media tree

Operator answers should be instant:

- "Where do I restore media app config from?"
  from the canonical backup lane for the final site; for home, that should be the home Proxmox VM backup on Synology
- "Where does live media content live?"
  `/srv/media`
- "Where do weird one-off media holds live?"
  an explicit non-runtime archive/hold path, not the live media root

## Boring Health Model

The canonical health checks should answer only these questions:

1. Is the `media-stack` VM up?
2. Is `/srv/media` mounted?
3. Is `/srv/appdata` mounted and writable?
4. Are all media containers healthy?
5. Is the app-state backup fresh?
6. Is `media` below the operational pressure guard?
7. Is the downloads backlog within threshold?

If those checks are green, the media estate should be considered boring enough.

## Explicit Anti-Patterns

The target state forbids:

- app SQLite databases on NFS
- planning from a partial service list that ignores active helper containers
- duplicate `Jellyseerr` surfaces
- separate download and streaming VMs unless there is a hard capacity reason
- Proxmox `dir` storage registered on `/media`
- cross-pool overlays that mask live runtime paths
- loose backup/archive residue on `/media`
- multiple live meanings for `downloads`
- agent/control-plane wiring that still points at split-era endpoints after cutover

## Migration Recommendation

### Target Recommendation

Use one new or repurposed home VM on `proxmox-home` as the canonical future `media-stack`.

If you want the shortest path, `VM 209` should be treated as the behavioral template for the future home VM,
not as the final long-term site.

Why:

- the existing split-era failure patterns were largely path and status drift problems, not raw compute problems,
- the home target already has a migration packet and readiness baseline in spine,
- a single home VM avoids carrying the same split-era complexity into the Beelink/Synology estate.

### Migration Waves

1. Finalize the home target contract.
   - Provision the canonical home media mount path required by readiness: `/mnt/media`.
   - Decide the Synology share layout that will back the future `/srv/media`.
   - Keep this machine-checkable in `home.media.readiness.baseline.yaml`.

2. Build the home media VM correctly the first time.
   - Create one Ubuntu VM on `proxmox-home`.
   - Give it local VM storage for `/srv/appdata`.
   - Mount the Synology media share into that VM as `/srv/media`.

3. Normalize paths before service cutover.
   - Present one canonical media mount as `/srv/media`.
   - Remove split per-app path drift such as `/downloads`, `/movies`, `/tv` as primary operator language.
   - Keep app configs using one shared `/data` style mount model.

4. Collapse service roles during migration, not before it.
   - Move `Jellyfin`, `Bazarr`, the kept request surface, and the *arr stack into the single home VM.
   - Remove duplicate `Jellyseerr`.
   - Keep the shop VMs provisioned during the rollback window.

5. Re-baseline backups and health.
   - One Proxmox VM backup truth for the home media VM.
   - One health status surface for the media VM.
   - One restore drill doc and one migration verification matrix.

6. Then simplify the shop rack.
   - Tombstone the shop media VMs after cutover verification passes.
   - Only then decide whether the shop `media` pool still deserves the 13TB drive upgrade.
   - Replace the SSD mirror separately from the media runtime consolidation.

## Final Boring Test

The media stack is boring when a new agent can answer these without exploration:

- What VM owns media runtime?
- Where does live media content live?
- Where does media app state live?
- Where is media app state restored from?
- Which public endpoints are intentional?
- Which path is safe for archive holds?
- Which path is safe to prune for regenerable pressure?

If any of those answers requires hunting across multiple VMs, duplicate services, or mixed mount semantics, the stack is still not boring enough.
