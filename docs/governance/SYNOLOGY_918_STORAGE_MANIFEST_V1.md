---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
scope: synology-storage-audit
version: 1.3
loop: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
---

# Synology DS918+ Storage Manifest v1

**Purpose**: Canonical runtime-truth map for the Synology DS918+ (`nas`, `100.102.199.111`) after the 730XD backup-plane cutover.

## Executive Summary

As of **2026-03-19**, the Synology share model is smaller and clearer than the old folder sprawl suggested:

1. **Canonical home backup surface** for `proxmox-home` VM/LXC artifacts under `/volume1/backups/proxmox_backups/dump/`.
2. **Canonical active media import/current-watch share** under `/volume1/media-staging/`.
3. **Canonical hold/review share** under `/volume1/media-holds/`.
4. **Explicit legacy backup tombstone subtree** under `/volume1/backups/_legacy_tombstones/`; not canonical, retained pending later delete/review.

There is **no live canonical `/volume1/media-home` share** today. The names `media-home`, `media`, `hot-media`, `live-library`, and `library-home` are empty unregistered placeholder directories, not real active shares. Cleanup was attempted in this wave, but their physical removal is still blocked without root/DSM-console privilege.

The Synology is **not** the canonical server-backup authority for shop or business workloads. The old business-app mirror lane stays cleared, and the historical shop exact-offsite lane plus the stale standalone backup lanes were renamed into `_legacy_tombstones` on `2026-03-19`. The canonical cold recovery plane for the shop environment now lives on the 730XD under `pve:/md1400/backup-cold/...`.

## Device Snapshot

| Field | Value |
|------|-------|
| Hostname | `synology918` |
| Tailscale IP | `100.102.199.111` |
| Model | Synology DS918+ |
| Total capacity | `20T` |
| Used | `7.2T` |
| Utilization | `38%` |

## Canonical Role Matrix

| Surface | Current Role | Canonical Authority | Live Proof |
|--------|--------------|---------------------|-----------|
| `/volume1/backups/apps/*` | Cleared legacy mirror root | 730XD `pve:/md1400/backup-cold/apps/*` | NAS app residue deleted on 2026-03-09 |
| `/volume1/backups/_legacy_tombstones/retired-20260319-shop-proxmox/vzdump/critical/` | Tombstoned historical shop residue | 730XD `pve:/md1400/backup-cold/vzdump/pve/` | Residue renamed into explicit tombstone subtree on 2026-03-19 |
| `/volume1/backups/proxmox_backups/dump/` | Canonical home VM/LXC backup surface | Synology | Latest `vm-100` artifact `2026-03-19`; latest `vm-106` artifact `2026-03-19`; latest `lxc-105` artifact `2026-03-15` |
| `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/*` | Tombstoned legacy mint-os residue only | Current Mint canonical planes on 730XD | Not active authority; moved out of active home backup root on 2026-03-19 |
| `/volume1/media-staging/` | Active media import/current-watch share | Synology | Exported to `10.0.0.106` and `10.0.0.179`; only populated/exported media share currently used by `media-home` VM 106 |
| `/volume1/media-holds/` | Active hold/review share | Synology | Exported to `10.0.0.179`; empty but intentionally retained for holds/review |
| `/volume1/im2ch`, `/volume1/photo-keepers`, `/volume1/documents`, `/volume1/homelab` | Home/personal canonical data | Synology | Live storage families remain mounted and in use |

## Share Surface Truth

Registered active shares proven from live SMB/NFS config:

- `/volume1/backups`
- `/volume1/media-staging`
- `/volume1/media-holds`
- `/volume1/im2ch`
- `/volume1/photo-keepers`
- `/volume1/photos`
- `/volume1/videos`
- `/volume1/archives`

Empty unregistered placeholder directories proven from live `/volume1` inspection:

- `/volume1/media-home`
- `/volume1/media`
- `/volume1/hot-media`
- `/volume1/live-library`
- `/volume1/library-home`
- `/volume1/tmp-spine-share`

Interpretation:

- These placeholder names are **not** active shares and are **not** canonical operator surfaces.
- They should not appear in future contracts as if they are real runtime/share authority.
- Physical removal is still pending a root/DSM-console path because the governed SSH user could prove they are unused but could not delete the root-owned directories.

## Cleared Business App Mirror

These NAS paths were deleted on `2026-03-09` after the green backup posture and restore-wave confidence window.

Current state:

- `/volume1/backups/apps/` exists as an empty root only.
- Canonical business/app recovery remains on `pve:/md1400/backup-cold/apps/...`.

Current canonical 730XD usage snapshot:

- `finance`: `1.4G`
- `infra-core`: `49M`
- `dev-tools`: `332M`
- `mint-data`: `35M`
- `communications`: `5.9M`

## Tombstoned Historical Shop Residue

The old shop exact-offsite lane on Synology has not been left in place as an active-looking root. It now lives only as an explicit tombstone.

Current state:

- `/volume1/backups/proxmox/` no longer exists as an active-looking root.
- The retained historical residue lives under `/volume1/backups/_legacy_tombstones/retired-20260319-shop-proxmox/`.
- Canonical cold recovery for shop guests lives on `pve:/md1400/backup-cold/vzdump/pve/`.

## Home-Local Canonical Surface

The Synology remains canonical for home-local backup storage and home/personal data.

| Path | Size | Role |
|------|------|------|
| `/volume1/backups/proxmox_backups/dump/` | `96G` | Home-local canonical backup surface |
| `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/` | `110G` | Tombstoned legacy mint-os residue, not canonical |
| `/volume1/im2ch/` | `2.3T` | Immich photo library |
| `/volume1/photo-keepers/` | `1.9T` | Personal photo archive |
| `/volume1/media-staging/` | `1.4T` | Active media import/current-watch share |
| `/volume1/media-holds/` | `0B` | Explicit hold/review share |
| `/volume1/documents/` | `81G` | Documents archive |
| `/volume1/homelab/` | `71G` | Homelab assets |

Current home backup artifacts:

- `vzdump-qemu-100-2026_03_19-03_00_02.vma.zst`
- `vzdump-qemu-106-2026_03_19-03_01_33.vma.zst`
- `vzdump-lxc-105-2026_03_15-04_00_03.tar.zst`

Interpretation:

- `vm-100`, `vm-106`, and `lxc-105` remain the active home backup exceptions on Synology.
- Synology is both the generation surface and the canonical recovery plane for these home artifacts.
- `media-home` VM 106 currently consumes `/volume1/media-staging`, not a separate `/volume1/media-home` share.

## Tombstoned Mint-OS Residue

The following legacy mint-os backup paths still exist on Synology, but they no longer sit inside the active home backup root:

- `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/minio/` — `110G`
- `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/postgres/` — `146M`
- `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/configs/` — `392K`
- `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue/strapi/` — `8K`

Observed characteristics:

- These files are stale legacy residue from `2025-12` through `2026-01`.
- They are not part of the current canonical Mint backup model.
- MinIO duplicate payload backup residue remains explicitly out of scope by policy.

## Explicit Legacy Backup Tombstones

The following standalone backup lanes were renamed into the explicit tombstone subtree on `2026-03-19` so they stop looking canonical:

- `/volume1/backups/_legacy_tombstones/retired-20260319-shop-proxmox/` — historical shop exact-offsite duplicate
- `/volume1/backups/_legacy_tombstones/retired-20260319-mint-os-standalone/` — historical standalone mint-os PostgreSQL lane
- `/volume1/backups/_legacy_tombstones/retired-20260319-home-assistant-standalone/` — historical standalone Home Assistant tar lane
- `/volume1/backups/_legacy_tombstones/retired-20260319-finance-standalone/` — historical standalone finance dump lane
- `/volume1/backups/_legacy_tombstones/retired-20260319-media-config-standalone/` — historical standalone media config dump lane

## Deletion / Retention Posture

Do **not** delete historical backups casually. Current operator posture is:

- Keep `/volume1/backups/proxmox_backups/dump/` as the canonical home backup surface.
- Keep `/volume1/media-staging/` as the only active media import/current-watch share until a dedicated hot-library share is actually instantiated.
- Keep `/volume1/media-holds/` as the explicit hold/review lane.
- Treat `/volume1/media-home`, `media`, `hot-media`, `live-library`, `library-home`, and `tmp-spine-share` as ghost placeholders, not canonical shares.
- Keep home and personal data families on Synology.
- Keep historical backup residue only under `/volume1/backups/_legacy_tombstones/` until a later delete/review wave makes retention decisions explicit.
