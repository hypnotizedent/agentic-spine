---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: synology-storage-audit
version: 1.1
loop: LOOP-BACKUP-PLANE-CONSOLIDATION-730XD-E2E-20260308
---

# Synology DS918+ Storage Manifest v1

**Purpose**: Canonical runtime-truth map for the Synology DS918+ (`nas`, `100.102.199.111`) after the 730XD backup-plane cutover.

## Executive Summary

As of **2026-03-08**, the Synology has exactly three canonical roles:

1. **Home-local primary backup surface** for `proxmox-home` VM/LXC artifacts.
2. **Selective shop exact-offsite target** for the feasible VM subset under `/volume1/backups/proxmox/vzdump/critical/`.
3. **Home/personal storage host** for Immich, photo archives, media staging, documents, and homelab payloads.

The Synology is **not** the canonical business app backup authority. Those paths now exist only as a **legacy grace mirror** while the canonical recovery plane lives on the 730XD at `pve:/md1400/backup-cold/apps/...`.

## Device Snapshot

| Field | Value |
|------|-------|
| Hostname | `synology918` |
| Tailscale IP | `100.102.199.111` |
| Model | Synology DS918+ |
| Total capacity | `20T` |
| Used | `8.2T` |
| Utilization | `43%` |

## Canonical Role Matrix

| Surface | Current Role | Canonical Authority | Live Proof |
|--------|--------------|---------------------|-----------|
| `/volume1/backups/apps/*` | Legacy grace mirror only | 730XD `pve:/md1400/backup-cold/apps/*` | Fresh 730XD finance/infra/dev-tools/mint-data/communications artifacts on 2026-03-08 |
| `/volume1/backups/proxmox/vzdump/critical/` | Selective exact-offsite for feasible shop VMs | Synology exact-offsite lane remains active | `vm-211` and `vm-213` artifacts present; offsite sync completed `2026-03-08 11:49:31 -04:00` |
| `/volume1/backups/proxmox_backups/dump/` | Home-local primary backup surface | Synology | Latest `vm-100` artifact `2026-03-08`; latest `lxc-105` artifact still present `2026-03-08` |
| `/volume1/im2ch`, `/volume1/photo-keepers`, `/volume1/media-staging`, `/volume1/documents`, `/volume1/homelab` | Home/personal canonical data | Synology | Live storage families remain mounted and in use |

## Business App Backup Mirror

These NAS paths are **not active authority**. They remain only as a grace-period mirror while 730XD is the canonical recovery plane.

| NAS Path | Size | Canonical 730XD Path | Current Truth |
|---------|------|----------------------|---------------|
| `/volume1/backups/apps/finance/` | `4.1M` | `/md1400/backup-cold/apps/finance/` | Legacy mirror only |
| `/volume1/backups/apps/ghostfolio/` | `76K` | `/md1400/backup-cold/apps/finance/ghostfolio/` | Legacy mirror only |
| `/volume1/backups/apps/paperless/` | `951M` | `/md1400/backup-cold/apps/finance/paperless/` | Legacy mirror only |
| `/volume1/backups/apps/mint-postgres/` | `18M` | `/md1400/backup-cold/apps/mint-data/postgres/` | Legacy mirror only |
| `/volume1/backups/apps/stalwart/` | `3.1M` | `/md1400/backup-cold/apps/communications/stalwart/` | Legacy mirror only |
| `/volume1/backups/apps/infisical/` | `11M` | `/md1400/backup-cold/apps/infra-core/infisical/` | Legacy mirror only |
| `/volume1/backups/apps/vaultwarden/` | `33M` | `/md1400/backup-cold/apps/infra-core/vaultwarden/` | Legacy mirror only |
| `/volume1/backups/apps/gitea/` | `198M` | `/md1400/backup-cold/apps/dev-tools/gitea/` | Legacy mirror only |
| `/volume1/backups/apps/mail-archiver/` | `0` | `/md1400/backup-cold/apps/communications/mail-archiver/` | Empty NAS residue, not authority |

Current canonical 730XD usage snapshot:

- `finance`: `1.4G`
- `infra-core`: `49M`
- `dev-tools`: `332M`
- `mint-data`: `35M`
- `communications`: `5.9M`

## Shop Exact-Offsite Posture

The shop exact-offsite lane on Synology remains **active for the feasible subset** and must not be described as deprecated.

**Canonical feasible exact-offsite set**:
- `204` `infra-core`
- `205` `observability`
- `206` `dev-tools`
- `207` `ai-consolidation`
- `209` `download-stack`
- `210` `streaming-stack`
- `211` `finance-stack`
- `213` `mint-apps`

**Current state**:
- Exact-offsite root: `/volume1/backups/proxmox/vzdump/critical/`
- Current size: `1018G`
- Latest verified `vm-211` artifact: `vzdump-qemu-211-2026_03_07-04_19_16.vma.zst`
- Latest verified `vm-213` artifact: `vzdump-qemu-213-2026_03_07-05_26_14.vma.zst`
- Duplicate offsite sync overlap was fixed on `2026-03-08` by adding a lockfile to `vzdump-offsite-sync.sh`
- The surviving authoritative run completed with `OK vm-213` and `=== offsite sync done ===`

**Non-feasible / explicit exceptions**:
- `vm-212` and `vm-214` remain size-based exact-offsite exceptions; app-level backup lanes are the compensating control.
- `vm-215` is not part of the current exact-offsite set.

## Home-Local Canonical Surface

The Synology remains canonical for home-local backup storage and home/personal data.

| Path | Size | Role |
|------|------|------|
| `/volume1/backups/proxmox_backups/dump/` | `60G` | Home-local primary backup surface |
| `/volume1/im2ch/` | `2.3T` | Immich photo library |
| `/volume1/photo-keepers/` | `1.9T` | Personal photo archive |
| `/volume1/media-staging/` | `602G` | Media staging |
| `/volume1/documents/` | `81G` | Documents archive |
| `/volume1/homelab/` | `71G` | Homelab assets |

Current home backup artifacts:

- `vzdump-qemu-100-2026_03_08-03_00_02.vma.zst`
- `vzdump-lxc-105-2026_03_08-04_00_02.tar.zst`

Interpretation:

- `vm-100` remains the active canonical Synology exception.
- `lxc-105` still has a fresh artifact on disk, but policy has already moved it out of the active exception set; do not treat that residue as new authority.

## Deletion / Retention Posture

Do **not** delete historical backups casually. Current operator posture is:

- Keep `/volume1/backups/apps/*` as a short grace mirror only; do not treat it as canonical.
- Keep `/volume1/backups/proxmox/vzdump/critical/` as the active exact-offsite surface for the feasible VM subset.
- Keep home-local and personal data families on Synology.
- Delete or retire stale legacy roots only through a separate governed cleanup lane with retention proof.
