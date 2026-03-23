# PVE Host Recovery Status Assessment

**Date**: 2026-03-23
**Wave**: LOOP-SHOP-STORAGE-CUTOVER-20260322

## Current State: PARTIALLY COVERED

Two ad-hoc backup locations exist but neither is automated or complete.

### Existing Artifacts

| Location | Date | Coverage |
|----------|------|----------|
| `/data/backups/pve-host-config-20260323/` | 2026-03-23 | /etc/pve, /etc/network, fstab, exports, GRUB, ZFS tuning, blacklists |
| `/md1400/backup-cold/pve-host-config/` | 2026-03-22 | /etc/pve tar + network + fstab + exports + hostname + hosts + zpool status |

### What's Captured

- `/etc/pve/` tree (VM configs, storage.cfg, PKI certs, keys)
- `/etc/network/interfaces` (bridge config)
- `/etc/fstab`, `/etc/exports`
- GRUB config (`intel_iommu=on iommu=pt`) — local only, NOT in cold tar
- ZFS ARC tuning (`zfs_arc_max=16G`) — local only
- SSH authorized_keys (18 keys, via /etc/pve/priv/)

### What's Missing (critical for clean rebuild)

| Artifact | Impact |
|----------|--------|
| `dpkg --get-selections` (831 packages) | Can't restore exact package set (tailscale, sanoid, nfs-kernel-server) |
| `/etc/apt/sources.list.d/` | Can't add correct repos (tailscale, pve-no-subscription) |
| `/etc/sanoid/sanoid.conf` | ZFS snapshot policy lost |
| `/usr/local/bin/` (5 scripts) | Cold-sync, offsite-sync, archive-smb-snapshot, zfs-snapshot |
| `/etc/cron.d/` custom files | Backup job schedules lost |
| `/etc/sysctl.d/`, `/etc/modprobe.d/` | Kernel tuning lost |
| Postfix relay config | Alert delivery broken |
| GRUB config in cold tar | Cold backup tar missing GRUB/ZFS tuning |

### Automation: NONE

No cron job, systemd timer, or governed capability exists for host config backup.
No entry in `backup.schedule.yaml` or `backup.inventory.yaml` for host config.

## Recommended: Weekly Host Config Backup

**Frequency**: Weekly (host config changes infrequently)

**Capture set**:
```
/etc/pve/                    # VM configs, storage, PKI
/etc/network/interfaces      # Bridge config
/etc/fstab, /etc/exports     # Mounts, NFS
/etc/default/grub            # Boot params
/etc/modprobe.d/             # Blacklists
/etc/sysctl.d/               # Kernel tuning
/etc/sanoid/sanoid.conf      # ZFS snapshots
/etc/cron.d/                 # Custom cron jobs
/usr/local/bin/              # Custom scripts
/etc/apt/sources.list*       # APT repos
dpkg --get-selections        # Package list
zpool status -v              # Pool geometry
pvesm status                 # Storage config
pveversion -v                # PVE version
```

**Destinations**: Both `/data/backups/pve-host-config/` AND `/md1400/backup-cold/pve-host-config/`

**Recovery path** (clean boring SSD swap):
1. Install PVE from ISO (same IP, hostname)
2. `zpool import tank; zpool import data; zpool import md1400`
3. Restore `/etc/pve/` from tar
4. Restore `/etc/network/interfaces`
5. Reinstall packages from saved list + APT sources
6. Restore custom scripts, cron, sanoid, tuning
7. Re-auth Tailscale

## Status: PARKED

Host recovery recurring job creation is parked for a follow-up wave.
The existing ad-hoc backups provide partial coverage for immediate needs.
