---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-12
scope: shop-media-pressure-closeout
---

# Shop Media Pressure Closure

## What was re-proved

- Observed on `pve` and `streaming-stack` between `2026-03-12T05:00:57Z` and `2026-03-12T05:08:17Z`.
- `media` is the pressured warm lane: `28.9T used`, about `189G free`, `99%` usage.
- `md1400` is the cold lane with headroom: `7.30T used`, `36.3T free`, `16%` usage.
- The canonical `/media` truth is the NFS export consumed by `download-stack` and `streaming-stack`, not the host-local child dataset view.

## Client-visible payload truth

Observed from `streaming-stack` over the live `/mnt/media` NFS mount:

| Path | Class | Usage | Notes |
| --- | --- | --- | --- |
| `/mnt/media/movies` | runtime | `9.6T` | Canonical movie library |
| `/mnt/media/tv` | runtime | `5.5T` | Canonical TV library |
| `/mnt/media/music` | runtime | `666G` | Canonical music library |
| `/mnt/media/movies-archive` | archive | `205G` | Radarr archive root reachable over `/media` |
| `/mnt/media/downloads` | runtime / regenerable | `2.7T` | Highest-value reclaim lane |
| `/mnt/media/backups` | compatibility hold | `103.5G` at observation time | Legacy warm-lane tarballs being drained to `md1400` |

## Local mount overlay drift

- `pve` local ZFS mountpoints show `media/movies`, `media/tv`, and `media/music` as empty child datasets.
- `md1400/media-cold/movies-archive` is mounted locally at `/media/movies-archive` and hides the host-local view there.
- Despite that, NFS consumers still observe the parent `/media` payload at all four paths.
- Conclusion: host-local `zfs list` and `du` are not sufficient to describe runtime-visible media payload. The NFS client view is the authority until the overlays are explicitly normalized.

## Reclaim and hold state

- Legacy `media-stack-2026-*.tar.gz` files were moved from `/media/backups` to `/md1400/media-cold/legacy-media-stack-backups`.
- Final observed state:
  - source remaining: `0` files / `6971392` bytes (`/media/backups` now only tiny residue)
  - destination present: `25` files / `182284270592` bytes
- Canonical media config backup truth already lives on `md1400` under `/md1400/backup-cold/apps/media-config` per `ops/bindings/backup.inventory.yaml`.
- `media@forensic-20260226-2325` remains retained as a forensic hold and currently consumes `278G`.
- That snapshot means warm-lane deletions do not reclaim matching space immediately; deleted blocks remain referenced by the snapshot until the hold is deliberately closed.

## Outcome

- The media lane is now classified instead of guessed.
- The legacy warm-lane backup tarballs are now physically off the media pool and parked on `md1400`.
- The biggest remaining reclaim path is `downloads`, not the canonical libraries.
- Shop is still not safe for drive changes because the warm lane remains at `99%` usage and the forensic snapshot absorbed the reclaimed blocks from the tarball drain.
