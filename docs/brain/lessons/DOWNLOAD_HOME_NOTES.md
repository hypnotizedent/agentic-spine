---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: home-lessons
---

# Download Home Notes

> Operational notes for the download-home *arr stack on proxmox-home LXC 103.

## Quick Reference

| Field | Value |
|-------|-------|
| LXC ID | 103 on proxmox-home |
| Tailscale IP | 100.125.138.110 |
| Local IP | 10.0.0.101 |
| Resources | 2c / 2GB RAM / 32GB disk |
| Status | **STOPPED** |
| Purpose | *arr stack for home media |

## Current State: STOPPED

All production media downloads handled by shop download-stack (VM 209, 24 containers). Home *arr stack was experimental, never reached production.

## Architecture (When Running)

Services: Radarr (:7878), Sonarr (:8989), Lidarr (:8686), Bazarr (:6767), Prowlarr (:9696), Sabnzbd (:8080).

Storage: `/mnt/staging/` (download staging, bind mount), `/mnt/media/` (NAS NFS mount).

## Known Issues

### ~~GAP-OP-118: Backup Failing~~ — FIXED

**Was:** Vzdump backup failed with NFS permission denied — `lxc-usernsexec` UID remapping (u:0:100000:65536) ran tar as host UID 100000 which couldn't write to Synology NFS `.tmp` staging dir.

**Fix (2026-02-12):** Added `tmpdir /var/tmp` to vzdump jobs `backup-home-p1-daily` and `backup-home-p2-weekly` in `/etc/pve/jobs.cfg`. This stages `pct.conf` on local disk (accessible to mapped UID) while the final `.tar.zst` archive writes to NFS outside the user namespace (as root). Validated: LXC 103 = 484MB, LXC 105 = 345MB.

### SSH Access Broken
`ssh root@download-home` returns `Permission denied (publickey)`. Needs authorized key added via `pct enter 103`.

### Volume Mapping Rule (from shop GAP-OP-109)
*arr root folder paths MUST have matching bind mounts in compose. Root folder `/movies` needs `/mnt/media/movies:/movies`, not just parent `/media`.

## Backup Strategy

- **VM-level:** vzdump P1 daily 03:15 (GAP-OP-118 FIXED — tmpdir /var/tmp)
- **App-level:** Not configured (LXC is stopped)

## Relationship to Shop

| Stack | Location | Containers | Status |
|-------|----------|------------|--------|
| download-home | LXC 103 (home) | 6 | Stopped |
| download-stack | VM 209 (shop) | 24 | Running |

No synchronization. Independent databases, indexers, and libraries.

## Pending Decision

Decide: re-enable download-home or permanently decommission LXC 103? If decommissioned, update MINILAB_SSOT and remove backup entries.

## Related Documents

- `docs/governance/MINILAB_SSOT.md`
- `docs/brain/lessons/MEDIA_DOWNLOAD_ARCHITECTURE.md`
- `docs/brain/lessons/MEDIA_STACK_LESSONS.md`
