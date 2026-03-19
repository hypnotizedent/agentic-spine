---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
scope: synology-storage-audit
version: 1.2
loop: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
---

# Synology DS918+ Storage Manifest v1

**Purpose**: Canonical runtime-truth map for the Synology DS918+ (`nas`, `100.102.199.111`) after the 730XD backup-plane cutover.

## Executive Summary

As of **2026-03-19**, the Synology has exactly two active roles plus one explicit legacy tombstone role:

1. **Canonical home backup surface** for `proxmox-home` VM/LXC artifacts under `/volume1/backups/proxmox_backups/dump/`.
2. **Home/personal storage host** for Immich, photo archives, media staging, documents, and homelab payloads.
3. **Explicit legacy backup tombstone subtree** under `/volume1/backups/_legacy_tombstones/`; not canonical, retained pending later delete/review.

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
| `/volume1/im2ch`, `/volume1/photo-keepers`, `/volume1/media-staging`, `/volume1/documents`, `/volume1/homelab` | Home/personal canonical data | Synology | Live storage families remain mounted and in use |

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
| `/volume1/media-staging/` | `602G` | Media staging |
| `/volume1/documents/` | `81G` | Documents archive |
| `/volume1/homelab/` | `71G` | Homelab assets |

Current home backup artifacts:

- `vzdump-qemu-100-2026_03_19-03_00_02.vma.zst`
- `vzdump-qemu-106-2026_03_19-03_01_33.vma.zst`
- `vzdump-lxc-105-2026_03_15-04_00_03.tar.zst`

Interpretation:

- `vm-100`, `vm-106`, and `lxc-105` remain the active home backup exceptions on Synology.
- Synology is both the generation surface and the canonical recovery plane for these home artifacts.

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
- Keep home and personal data families on Synology.
- Keep historical backup residue only under `/volume1/backups/_legacy_tombstones/` until a later delete/review wave makes retention decisions explicit.
