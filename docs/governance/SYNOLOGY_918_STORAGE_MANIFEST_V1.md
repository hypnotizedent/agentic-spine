---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-22
scope: synology-storage-audit
version: 1.4
loop: LOOP-STORAGE-SCAFFOLD-CANONICALIZATION-20260322
---

# Synology DS918+ Storage Manifest v1

**Purpose**: describe the Synology home plane through the same boring storage scaffold semantics used for md1400, so agents do not rediscover stale backup or personal-data assumptions.

Machine-readable scaffold authority: `ops/bindings/storage.scaffold.authority.yaml`

## Executive Summary

As of **March 22, 2026**, the scoped Synology truth is:

1. `/volume1/backups/proxmox_backups/dump/` remains the **canonical home VM/LXC backup** surface.
2. `/volume1/backups/apps/media-config/` is a **live canonical primary config backup** surface for `media-home`; therefore `/volume1/backups/apps/` is **not** globally cleared.
3. `/volume1/backups/_legacy_tombstones/` is an **intentional retained tombstone subtree**, not active authority.
4. `/volume1/media-staging/` and `/volume1/media-holds/` remain canonical home media surfaces.
5. `/volume1/documents/` is now **drained and empty**, not canonical.
6. `/volume1/homelab/`, `/volume1/backups/infrastructure/`, and `/volume1/backups/devices/` remain **review-pending** durable weight, not auto-delete candidates.
7. `/volume1/backups/synoreport/` is **defect cruft**.

This wave did **not** broaden into photo/video/Immich cleanup. `photo-keepers`, `photos`, `videos`, and `im2ch` were not reclassified beyond preserving their existing posture.

## Device Snapshot

| Field | Value |
| --- | --- |
| Hostname | `synology918` |
| Tailscale IP | `100.102.199.111` |
| Model | Synology DS918+ |
| Total capacity | `20T` |
| Used | `7.2T` |
| Utilization | `38%` |

## Shared Scaffold View

| Path | Scaffold Class | Canonicality | Current Truth |
| --- | --- | --- | --- |
| `/volume1/backups/proxmox_backups/dump/` | `backup_primary` | canonical | Canonical home VM/LXC backup lane |
| `/volume1/backups/apps/` | `review_pending` | mixed | Parent root contains live canonical subpath; not globally cleared |
| `/volume1/backups/apps/media-config/` | `backup_primary` | canonical | Canonical primary `media-home` config backup lane |
| `/volume1/backups/_legacy_tombstones/` | `tombstone_retained` | noncanonical | Retained historical backup lanes |
| `/volume1/backups/infrastructure/` | `review_pending` | unknown | Fresh retained weight; lifecycle narrowing still missing |
| `/volume1/backups/devices/` | `review_pending` | unknown | Retained device residue with backup hygiene drift |
| `/volume1/backups/synoreport/` | `defect_cruft` | noncanonical | Generated residue |
| `/volume1/media-staging/` | `personal_live` | canonical | Active home media import/current-watch surface |
| `/volume1/media-holds/` | `review_hold` | canonical | Explicit hold/review share |
| `/volume1/documents/` | `drained_retired` | drained | Empty root; no live authority remains |
| `/volume1/homelab/` | `review_pending` | unknown | Retained but unresolved durable weight |
| `/volume1/homelab/images/` | `review_pending` | unknown | Old VM image residue |
| `/volume1/homelab/template/` | `review_pending` | unknown | Old template residue |

## Canonical Role Matrix

| Surface | Current Role | Canonical Authority | Live Proof |
| --- | --- | --- | --- |
| `/volume1/backups/proxmox_backups/dump/` | Canonical home VM/LXC backup surface | Synology | Latest `vm-100` and `vm-106` artifacts landed on **2026-03-21**; latest `lxc-105` on **2026-03-15** |
| `/volume1/backups/apps/media-config/` | Canonical primary media-home config backup surface | Synology | Latest `media-home-config-20260321-180711.tar.gz` landed on **2026-03-21 13:09:32 UTC** |
| `/volume1/backups/_legacy_tombstones/retired-20260319-shop-proxmox/vzdump/critical/` | Tombstoned historical shop residue | 730XD `pve:/md1400/backup-cold/vzdump/pve/` | Retained only as explicit tombstone |
| `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/*` | Tombstoned legacy mint-os residue | Current Mint canonical planes on 730XD | Not active authority |
| `/volume1/media-staging/` | Active home media surface | Synology | Declared canonical media root in lifecycle registry |
| `/volume1/media-holds/` | Hold/review share | Synology | Declared allowed secondary hold lane in lifecycle registry |
| `/volume1/documents/` | Drained retired root | None | Live count is `0` on March 22, 2026 |
| `/volume1/homelab/` | Review-pending retained root | Unresolved | Old weight remains; no 2026 writes observed under `images/` or `template/` |

## Active Backup Surfaces

### Home-local Primary

- Path: `/volume1/backups/proxmox_backups/dump/`
- Current size: `114G`
- Latest `vm-100`: `vzdump-qemu-100-2026_03_21-03_00_01.vma.zst`
- Latest `vm-106`: `vzdump-qemu-106-2026_03_21-03_01_31.vma.zst`
- Latest `lxc-105`: `vzdump-lxc-105-2026_03_15-04_00_03.tar.zst`

### Media-home Config Primary

- Path: `/volume1/backups/apps/media-config/`
- Current size: `4.6G`
- Latest artifact: `media-home/media-home-config-20260321-180711.tar.gz`
- Canonicality: primary
- Secondary cold copy: `pve:/md1400/backup-cold/apps/media-config`

## Retained Tombstones

Retained on purpose under `/volume1/backups/_legacy_tombstones/`:

- `retired-20260319-shop-proxmox/`
- `retired-20260319-mint-os-standalone/`
- `retired-20260319-mint-os-home-residue/`
- `retired-20260319-home-assistant-standalone/`
- `retired-20260319-finance-standalone/`
- `retired-20260319-media-config-standalone/`

Operator note:

- These are **not** canonical backup roots.
- One nested `.DS_Store` under `retired-20260319-mint-os-home-residue/configs/` remained root-owned and blocked from sidecar cleanup in this wave.

## Review-Pending Weight

These roots are retained intentionally but not yet narrow enough to be called canonical or dead:

| Path | Size | Latest Observed Touch | Why It Is Not Auto-delete |
| --- | --- | --- | --- |
| `/volume1/backups/infrastructure/` | `3.1G` | `2026-01-17T02:58:30Z` | Fresh retained backup payload with no narrow lifecycle contract yet |
| `/volume1/backups/devices/` | `462M` | `2026-02-01T09:00:05Z` | Live device residue remains; `ronny-macbook` capture includes `.ssh/sockets` |
| `/volume1/homelab/` | `71G` | mixed | Root retained; this wave did not inspect or mutate `photo-cleanup/` |
| `/volume1/homelab/images/` | `68G` | `2025-07-19T20:55:56Z` | Old VM image payload with no 2026 writes observed |
| `/volume1/homelab/template/` | `3.0G` | `2025-02-16T22:49:40Z` | Old template payload with no 2026 writes observed |

## Defect Cruft

High-confidence cruft in scoped backup roots:

- `/volume1/backups/synoreport/` — generated report residue, latest observed payload touch `2025-12-27T03:55:38Z`
- `#recycle`, `@eaDir`, `.DS_Store` sidecars under scoped roots were deleted where permissions allowed

Blocked cleanup:

- `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/configs/.DS_Store` remained root-owned and could not be removed through the governed SSH lane

## Share Surface Truth

Registered active shares still relevant to this wave:

- `/volume1/backups`
- `/volume1/media-staging`
- `/volume1/media-holds`

Ghost placeholders remain non-canonical:

- `/volume1/media-home`
- `/volume1/media`
- `/volume1/hot-media`
- `/volume1/live-library`
- `/volume1/library-home`
- `/volume1/tmp-spine-share`

## Retention / Delete Posture

- Keep `/volume1/backups/proxmox_backups/dump/` as the canonical home backup surface.
- Keep `/volume1/backups/apps/media-config/` as the canonical primary `media-home` config backup surface.
- Keep `/volume1/backups/_legacy_tombstones/` as retained non-canonical historical weight until a later review/delete wave.
- Keep `/volume1/media-staging/` and `/volume1/media-holds/` in their current canonical roles.
- Treat `/volume1/documents/` as drained retired; do not reintroduce business payload there.
- Treat `/volume1/backups/infrastructure/`, `/volume1/backups/devices/`, and `/volume1/homelab/*` as review-pending, not blind-delete targets.
