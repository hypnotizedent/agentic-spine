---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-09
scope: synology-storage-audit
version: 1.1
loop: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
---

# Synology DS918+ Storage Manifest v1

**Purpose**: Canonical runtime-truth map for the Synology DS918+ (`nas`, `100.102.199.111`) after the 730XD backup-plane cutover.

## Executive Summary

As of **2026-03-09**, the Synology has exactly three active roles:

1. **Canonical home backup surface** for `proxmox-home` VM/LXC artifacts under `/volume1/backups/proxmox_backups/dump/`.
2. **Home/personal storage host** for Immich, photo archives, media staging, documents, and homelab payloads.
3. **Reviewed legacy mint-os residue** under `/volume1/backups/proxmox_backups/mint-os/*`; not canonical, retained pending explicit delete.

The Synology is **not** the canonical server-backup authority for shop or business workloads. The old business-app mirror lane and historical shop exact-offsite lane were deleted on `2026-03-09`. The canonical cold recovery plane for the shop environment now lives on the 730XD under `pve:/md1400/backup-cold/...`.

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
| `/volume1/backups/proxmox/vzdump/critical/` | Cleared legacy residue root | 730XD `pve:/md1400/backup-cold/vzdump/pve/` | Legacy exact-offsite residue deleted on 2026-03-09 |
| `/volume1/backups/proxmox_backups/dump/` | Canonical home VM/LXC backup surface | Synology | Latest `vm-100` artifact `2026-03-08`; latest `lxc-105` artifact present `2026-03-08` |
| `/volume1/backups/proxmox_backups/mint-os/*` | Reviewed legacy residue only | Current Mint canonical planes on 730XD | Not active authority; reviewed 2026-03-09 |
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

## Cleared Historical Shop Residue

The old shop exact-offsite lane on Synology has been deleted.

Current state:

- `/volume1/backups/proxmox/vzdump/critical/` is empty/absent after the 2026-03-09 cleanup.
- Canonical cold recovery for shop guests lives on `pve:/md1400/backup-cold/vzdump/pve/`.

## Home-Local Canonical Surface

The Synology remains canonical for home-local backup storage and home/personal data.

| Path | Size | Role |
|------|------|------|
| `/volume1/backups/proxmox_backups/dump/` | `58G` | Home-local canonical backup surface |
| `/volume1/backups/proxmox_backups/mint-os/` | `110G` | Reviewed legacy mint-os residue, not canonical |
| `/volume1/im2ch/` | `2.3T` | Immich photo library |
| `/volume1/photo-keepers/` | `1.9T` | Personal photo archive |
| `/volume1/media-staging/` | `602G` | Media staging |
| `/volume1/documents/` | `81G` | Documents archive |
| `/volume1/homelab/` | `71G` | Homelab assets |

Current home backup artifacts:

- `vzdump-qemu-100-2026_03_08-03_00_02.vma.zst`
- `vzdump-lxc-105-2026_03_08-04_00_02.tar.zst`

Interpretation:

- `vm-100` and `lxc-105` remain the active home backup exceptions on Synology.
- Synology is both the generation surface and the canonical recovery plane for these home artifacts.

## Reviewed Mint-OS Residue

The following legacy mint-os backup paths still exist on Synology and were reviewed but not deleted in this wave:

- `/volume1/backups/proxmox_backups/mint-os/minio/` — `110G`
- `/volume1/backups/proxmox_backups/mint-os/postgres/` — `146M`
- `/volume1/backups/proxmox_backups/mint-os/configs/` — `392K`
- `/volume1/backups/proxmox_backups/mint-os/strapi/` — `8K`

Observed characteristics:

- These files are stale legacy residue from `2025-12` through `2026-01`.
- They are not part of the current canonical Mint backup model.
- MinIO duplicate payload backup residue remains explicitly out of scope by policy.

## Deletion / Retention Posture

Do **not** delete historical backups casually. Current operator posture is:

- Keep `/volume1/backups/proxmox_backups/dump/` as the canonical home backup surface.
- Keep home and personal data families on Synology.
- Review `/volume1/backups/proxmox_backups/mint-os/*` before delete; current policy suggests it is removable legacy residue, but it was retained in this wave pending explicit delete.
