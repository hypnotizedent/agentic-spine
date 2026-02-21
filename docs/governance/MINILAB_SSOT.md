---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-20
verification_method: live-system-inspection
scope: home-infrastructure
github_issue: "#625"
parent_receipts:
  - "DISCOVERY_2026-01-21"
---

# MINILAB SSOT

> **This is the SINGLE SOURCE OF TRUTH for the Home Minilab infrastructure.**
>
> Covers: Beelink (proxmox-home), Synology NAS, VMs/LXCs, and home network.
> For device identity and Tailscale config, see [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md).
>
> **Last Verified:** February 20, 2026

---

## Quick Reference

| System | IP | Access |
|--------|-----|--------|
| proxmox-home | 100.103.99.62 | `ssh root@proxmox-home` |
| NAS (Synology) | 100.102.199.111 | https://nas:5001 |
| Home Assistant | 100.67.120.1 | http://ha:8123 |
| Vaultwarden (decommissioned) | 100.93.142.63 | Decommissioned 2026-02-16 (primary on infra-core) |
| Pi-hole | 100.105.148.96 | http://pihole-home/admin |

---

## Beelink Mini PC (proxmox-home)

### Hardware Specifications

| Component | Specification | Verified |
|-----------|---------------|----------|
| **Model** | Beelink SER7 | 2026-02-10 |
| **CPU** | AMD Ryzen 7 7840HS | 2026-01-21 |
| **Cores/Threads** | 8 cores / 16 threads | 2026-01-21 |
| **RAM** | 27GB (reported) | 2026-01-21 |
| **Storage** | 500GB NVMe (local-lvm) | - |
| **OS** | Proxmox VE 8.4.1 | 2026-01-21 |
| **Kernel** | 6.8.12-10-pve | 2026-01-21 |

### Network Configuration

| Interface | IP | Notes |
|-----------|-----|-------|
| Tailscale | 100.103.99.62 | Primary access |
| Local | 10.0.0.179 | Home LAN |
| Gateway | 10.0.0.1 | Ubiquiti UDR |

### PVE Node-Name Status

> **RESOLVED (2026-02-10):** Hostname is `pve` — PVE node configs live under `/etc/pve/nodes/pve/`
> which matches the hostname. All tooling (`qm list`, `pct list`, `vzdump`) is functional.
> The earlier plan to rename to `proxmox-home` was abandoned; hostname stays `pve` by exception policy.
> See: `LOOP-PVE-NODE-NAME-FIX-HOME-20260209` (closed).

### Resource Usage (2026-02-07)

| Metric | Value |
|--------|-------|
| Uptime | 42 days |
| Load Average | 0.22, 0.19, 0.14 |
| RAM | 8.8GB / 27GB used (14GB free) |
| Root FS | 11GB / 94GB (13%) |

---

## Synology DS918+ NAS

### Hardware Specifications

| Component | Specification |
|-----------|---------------|
| **Model** | Synology DS918+ |
| **CPU** | Intel Celeron J3455 (4 cores) |
| **RAM** | 4GB (expandable to 8GB) |
| **Drive Bays** | 4x 3.5" SATA + 2x M.2 NVMe |
| **Network** | 2x 1GbE (link aggregation capable) |

### Drive Inventory (verified 2026-02-07)

| Bay | Model | Capacity | Type |
|-----|-------|----------|------|
| sda (Bay 1) | Seagate IronWolf Pro ST16000NE000 | 16TB | HDD |
| sdb (Bay 2) | WD Red WD30EFRX | 3TB | HDD |
| sdc (Bay 3) | WD Red WD30EFRX | 3TB | HDD |
| sdd (Bay 4) | Seagate IronWolf Pro ST16000NE000 | 16TB | HDD |
| nvme0 (M.2 Slot 1) | Crucial P1 CT1000P1SSD8 | 1TB | NVMe SSD |
| nvme1 (M.2 Slot 2) | Crucial P1 CT1000P1SSD8 | 1TB | NVMe SSD |

### RAID Configuration (SHR)

| Array | Level | Disks | Size | Purpose |
|-------|-------|-------|------|---------|
| md0 | RAID1 | sda1/sdb1/sdc1/sdd1 | 8GB | System partition |
| md1 | RAID1 | sda2/sdb2/sdc2/sdd2 | 2GB | Swap |
| md2 | RAID5 | sda5/sdb5/sdc5/sdd5 | 8.7TB | Data (all 4 drives) |
| md3 | RAID1 | sda6/sdd6 | 12.7TB | Data (16TB pair only) |
| md4 | RAID1 | nvme0n1p1/nvme1n1p1 | 976GB | SSD read/write cache |

**Note:** md2 + md3 combine as SHR to form the ~20TB `volume1`. The NVMe RAID1 pair serves as SSD cache.

### Network Configuration

| Interface | IP | Notes |
|-----------|-----|-------|
| Tailscale | 100.102.199.111 | `nas` hostname |
| Local | 10.0.0.150 | Home LAN |
| DSM Web UI | https://10.0.0.150:5001 | - |

### Storage Volumes

| Volume | Capacity | Used | Purpose |
|--------|----------|------|---------|
| volume1 | 20TB | 7.1TB (37%) | Primary storage |

### NFS Exports

| Export Path | Mount Point | Consumers |
|-------------|-------------|-----------|
| /volume1/homelab | /mnt/pve/synology918 | proxmox-home |
| /volume1/backups/proxmox_backups | /mnt/pve/synology-backups | proxmox-home vzdump |
| /volume1/im2ch | - | Immich photos |
| /volume1/archives | - | Archive storage |
| /volume1/photos | - | Photo library |
| /volume1/videos | - | Video library |
| /volume1/backups | - | General backups |

---

## VM/LXC Inventory

### Virtual Machines

| VMID | Hostname | Tailscale IP | RAM | Disk | Status |
|------|----------|--------------|-----|------|--------|
| 100 | homeassistant | 100.67.120.1 | 4GB | 32GB | Running |
| 101 | immich | — | — | — | **Destroyed** 2026-02-20 (shop VM 203 is canonical) |
| 102 | vaultwarden | 100.93.142.63 | 2GB | 16GB | **Decommissioned** (2026-02-16; superseded by infra-core VM 204) |

### LXC Containers

| VMID | Hostname | Tailscale IP | Status | Purpose |
|------|----------|--------------|--------|---------|
| 103 | download-home | — | **Destroyed** 2026-02-20 | Shop download-stack (VM 209) is canonical |
| 105 | pihole-home | 100.105.148.96 | **Running** | Home DNS + ad-blocking |

### VM Details

#### VM 100: Home Assistant

| Field | Value |
|-------|-------|
| Tailscale IP | 100.67.120.1 |
| Local IP | 10.0.0.100 |
| Web UI | http://ha:8123 |
| Purpose | Home automation hub |
| Integrations | Zigbee (SLZB-06), Z-Wave (TubesZB), UniFi |

#### VM 101: Immich (Home) — DESTROYED

| Field | Value |
|-------|-------|
| Status | **Destroyed** 2026-02-20 (`qm destroy 101 --purge`) |
| Final backup | `vzdump-qemu-101-2026_02_15-04_00_03.vma.zst` (18GB on NAS) |
| Successor | Shop Immich (VM 203, 100.114.101.50) |

#### VM 102: Vaultwarden (DECOMMISSIONED)

| Field | Value |
|-------|-------|
| Tailscale IP | 100.93.142.63 |
| Status | **Decommissioned** 2026-02-16 |
| Purpose | Password manager (Bitwarden-compatible) — superseded by infra-core (VM 204) |

**Note:** Final backup `vzdump-qemu-102-2026_02_15-03_01_25.vma.zst` on NAS. Retained as rollback source only.

#### LXC 103: download-home — DESTROYED

| Field | Value |
|-------|-------|
| Status | **Destroyed** 2026-02-20 (`pct destroy 103 --purge`) |
| Final backup | `vzdump-lxc-103-2026_02_20-03_15_03.tar.zst` (485MB on NAS) |
| Successor | Shop download-stack (VM 209, 100.107.36.76) |

#### LXC 105: pihole-home

| Field | Value |
|-------|-------|
| Tailscale IP | 100.105.148.96 |
| Purpose | Home DNS server + ad-blocking |
| Status | **Running** (reactivated 2026-02-21) |

---

## Home Network Summary (10.0.0.0/24)

### IP Address Map

| Device | Local IP | Tailscale IP | Role |
|--------|----------|--------------|------|
| Ubiquiti UDR | 10.0.0.1 | - | Gateway, WiFi AP, DHCP |
| Synology NAS | 10.0.0.150 | 100.102.199.111 | Storage |
| proxmox-home | 10.0.0.179 | 100.103.99.62 | Hypervisor |
| SLZB-06 (Zigbee) | 10.0.0.51 | - | Zigbee coordinator |
| SLZB-06MU (Matter) | 10.0.0.52 | - | Zigbee + Matter |
| TubesZB (Z-Wave) | 10.0.0.90 | - | Z-Wave coordinator |
| homeassistant | 10.0.0.100 | 100.67.120.1 | VM 100 |
| vaultwarden | 10.0.0.102 | 100.93.142.63 | VM 102 |
| pihole-home | 10.0.0.53 | 100.105.148.96 | LXC 105 (active) |
| ~~download-home~~ | ~~10.0.0.103~~ | — | LXC 103 (destroyed 2026-02-20) |

### Network Configuration

| Setting | Value |
|---------|-------|
| Subnet | 10.0.0.0/24 |
| Gateway | 10.0.0.1 (UDR) |
| DHCP Range | 10.0.0.200 - 10.0.0.254 |
| DHCP DNS | 10.0.0.53 primary (pihole-home), 10.0.0.1 fallback |
| WiFi SSID | pogodobby |

### Radio Coordinators

| Device | Model | IP | Protocol | Status |
|--------|-------|----|----------|--------|
| SLZB-06 | SMLIGHT SLZB-06 | 10.0.0.51 | Zigbee (CC2652P) | Online |
| SLZB-06MU | SMLIGHT SLZB-06MU | 10.0.0.52 | Zigbee + Matter | Online |
| TubesZB | TubesZB Z-Wave | 10.0.0.90 | Z-Wave | Online |

---

## Storage Configuration

### Proxmox Storage

```
dir: local
    path /var/lib/vz
    content vztmpl,backup,iso

lvmthin: local-lvm
    thinpool data
    vgname pve
    content images,rootdir

nfs: synology918
    export /volume1/homelab
    path /mnt/pve/synology918
    server 10.0.0.150
    content vztmpl,rootdir,iso,import,images,snippets

nfs: synology-backups
    export /volume1/backups/proxmox_backups
    path /mnt/pve/synology-backups
    server 10.0.0.150
    content backup
    prune-backups keep-last=3
```

### Disk Usage

| Filesystem | Size | Used | Avail | Mount |
|------------|------|------|-------|-------|
| /dev/mapper/pve-root | 94GB | 11GB | 79GB | / |
| synology-backups | 20TB | 7.1TB | 13TB | /mnt/pve/synology-backups |

---

## Backup Configuration

### Proxmox vzdump

> **Backups ENABLED as of 2026-02-11.** 2 jobs enabled, 1 job intentionally disabled for stopped LXC 103.
> See: [HOME_BACKUP_STRATEGY.md](HOME_BACKUP_STRATEGY.md) for full strategy.

| Job | Tier | Target | Schedule | Retention | Storage | Enabled |
|-----|------|--------|----------|-----------|---------|---------|
| backup-home-p0-daily | P0 (Critical) | VM 100 | Daily 03:00 | keep-last=3 | synology-backups | **Yes** |
| backup-home-p1-daily | P1 (Important) | LXC 103 | Daily 03:15 | keep-last=3 | synology-backups | **No** (disabled 2026-02-20) |
| backup-home-p2-weekly | P2 (Deferrable) | LXC 105 | Sun 04:00 | keep-last=2 | synology-backups | **Yes** |

**Validation:** VM 102 vzdump completed 2026-02-11 — artifact `vzdump-qemu-102-2026_02_11-08_53_32.vma.zst` (3.87GB) confirmed on NAS.

**Email notifications:** P0 job sends to ronny@hantash.com on all events.

### NAS Backups (Hyper Backup)

**No Hyper Backup tasks configured.** Package is installed and enabled but the task database is empty. NAS-to-offsite DR is deferred (see HOME_BACKUP_STRATEGY.md).

### NAS Backup Targets (vzdump destinations)

| Target | Path | Consumers | Status |
|--------|------|-----------|--------|
| Proxmox vzdump | `/volume1/backups/proxmox_backups` | proxmox-home vzdump | **Active** (2 jobs enabled, 1 disabled) |
| Mint-OS PostgreSQL | `/volume1/backups/mint-os/postgres/` | docker-host | Unverified |
| Mint-OS configs | `/volume1/backups/mint-os/configs/` | docker-host | Unverified |
| Home Assistant | `/volume1/backups/homeassistant_backups/` | VM 100 | Unverified |

---

## Compatibility Hints

### Workload Recommendations

| Workload | Recommended Host | Reason |
|----------|------------------|--------|
| Frigate NVR | proxmox-home | Has iGPU for video decode |
| Photo ML | immich (VM 101) | Already has ML container |
| Heavy DB | NAS + SSD cache | NAS has caching capability |
| Pi-hole secondary | pihole-home LXC | Active home-local DNS filtering path |

### Resource Constraints

| Host | Limitation | Mitigation |
|------|------------|------------|
| proxmox-home | 27GB RAM shared | Don't run heavy ML locally |
| NAS | 4GB RAM | Use for storage, not compute |
| Immich VM | 16GB RAM | Sufficient for ML inference |

### Future Expansion

| Upgrade | Benefit | Priority |
|---------|---------|----------|
| NAS RAM to 8GB | Better caching | LOW |
| Add NVMe to NAS | SSD cache for DBs | MEDIUM |
| Frigate on proxmox-home | Local NVR processing | MEDIUM |

---

## Verification Commands

```bash
# Host reachability
ssh proxmox-home uptime

# VM/LXC inventory
ssh proxmox-home "qm list && pct list"

# NAS connectivity
ping -c1 nas

# Home Assistant
curl -s http://ha:8123/api/ -H "Authorization: Bearer $HA_TOKEN"

# Vaultwarden
curl -s http://vault:8080/
```

---

## Cronjobs / Scheduled Tasks

### proxmox-home (root)

> **Note:** As of 2026-01-21, `crontab -l` returns `no crontab for root`. Backup jobs are managed via PVE vzdump scheduler (not cron).

**Planned (not yet enabled):**

| Schedule | Script | Purpose | Status |
|----------|--------|---------|--------|
| `30 3 * * *` | `backup-ha.sh` | Home Assistant backup | PENDING |
| `0 3 * * *` | `backup-immich-db.sh` | Immich DB backup | PENDING (VM stopped) |
| `0 5 * * 0` | `backup-immich-library.sh` | Immich library (weekly) | PENDING (VM stopped) |
| `*/5 * * * *` | `transfer-to-remote.sh` | Rsync staging to remote | PENDING |

### System-Managed Schedules

| System | Schedule | Task | Status |
|--------|----------|------|--------|
| Proxmox vzdump P0 | Daily 03:00 | VM 100 backup to synology-backups | **ENABLED** |
| Proxmox vzdump P1 | Daily 03:15 | LXC 103 backup to synology-backups | **DISABLED** (2026-02-20) |
| Proxmox vzdump P2 | Weekly Sun 04:00 | LXC 105 backup to synology-backups | **ENABLED** |
| Synology DSM | Weekly | RAID scrub | ACTIVE |
| Pi-hole | Weekly | Gravity update | ACTIVE (when LXC running) |

---

## Known Issues

| Issue | Status | Severity | Notes |
|-------|--------|----------|-------|
| PVE node-name mismatch | **RESOLVED** | ~~CRITICAL~~ | Hostname canonicalized to `proxmox-home`; node path migrated and tooling restored (2026-02-20). |
| vzdump jobs disabled | **RESOLVED** | ~~HIGH~~ | 3 tiered jobs enabled 2026-02-11. See Backup Configuration. |
| No Hyper Backup tasks | OPEN | MEDIUM | NAS has no backup destinations configured. Deferred. |
| VM 101 (immich) | **RESOLVED** | ~~MEDIUM~~ | Destroyed 2026-02-20. Shop VM 203 is canonical. |
| LXC 103 (download-home) | **RESOLVED** | ~~MEDIUM~~ | Soft-decommissioned 2026-02-21; removed from active-access expectations. |
| LXC 105 (pihole-home) | **RESOLVED** | ~~MEDIUM~~ | Reactivated 2026-02-21; home DHCP DNS routed back to pihole-home. |
| download-home SSH | **RESOLVED** | ~~MEDIUM~~ | Expectation removed by decommission decision (non-destructive). |
| Immich home vs shop | **RESOLVED** | ~~LOW~~ | Home instance destroyed 2026-02-20. Shop VM 203 is sole instance. |
| UDR DNS not using pihole | **RESOLVED** | ~~LOW~~ | DHCP DNS now set to 10.0.0.53 primary with 10.0.0.1 fallback. |

---

## Open Loops

No open baseline loops. `OL_HOME_BASELINE_FINISH` closed 2026-02-07.

**Resolved 2026-02-07:**
- NAS SSH access: works as `ronadmin` via Tailscale (100.102.199.111)
- NAS drive inventory: 4 SATA (2x16TB IronWolf Pro + 2x3TB WD Red) + 2x1TB NVMe cache
- NAS RAID: SHR with NVMe RAID1 cache — verified via `/proc/mdstat`
- proxmox-home crontab: confirmed empty (no root crontab)
- vzdump backup jobs: 3 exist, all disabled
- Hyper Backup: installed, no tasks configured
- UDR DHCP DNS: 10.0.0.1 (UDR itself)

**New issues discovered (require separate loops):**
- GAP-OP-014: PVE node-name mismatch — **RESOLVED** (hostname is `pve`, closed 2026-02-10)
- GAP-OP-015: No naming governance policy (root cause of GAP-OP-014)

---

## Evidence / Receipts

### 2026-02-11 Backup Enablement

| Item | Value |
|------|-------|
| Method | SSH to proxmox-home (live config + validation vzdump) |
| Changes | storage.cfg retention, jobs.cfg rewritten, vzdump 102 validated |
| Artifact | `vzdump-qemu-102-2026_02_11-08_53_32.vma.zst` (3.87GB on NAS) |
| Loop | `LOOP-HOME-BACKUP-INFRASTRUCTURE-ENABLE-20260209` |

### 2026-02-07 Home Baseline Completion Audit

| Item | Value |
|------|-------|
| Method | SSH to proxmox-home + NAS (live system inspection) |
| Hosts Verified | proxmox-home (100.103.99.62), NAS (100.102.199.111) |
| On-site confirmation | UDR DNS, Hyper Backup, device inventory (Ronny, 2026-02-07) |
| Loop closed | `OL_HOME_BASELINE_FINISH` |

**Key findings:**
- PVE 8.4.1 confirmed, hostname `pve` (tooling functional)
- NAS drives: 2x Seagate 16TB + 2x WD 3TB + 2x Crucial 1TB NVMe (SHR + cache)
- All 3 vzdump backup jobs disabled (now fixed)
- No Hyper Backup tasks configured
- VM 101 (immich) stopped
- NAS SSH works as `ronadmin`
- download-home moved to soft-decommissioned history (no active SSH expectation)

### 2026-01-21 Infrastructure Discovery

| Item | Value |
|------|-------|
| Source | DISCOVERY_2026-01-21.md |
| Method | SSH + command capture |
| Hosts Verified | proxmox-home, VMs 100-102, LXCs 103/105 |

**Commands run:**
- `pveversion -v` → PVE 8.4.1
- `qm list` / `pct list` → VM/LXC inventory
- `pvesm status` → Storage configuration
- `df -h` → Disk usage

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [HOME_BACKUP_STRATEGY.md](HOME_BACKUP_STRATEGY.md) | Home backup strategy |
| [BACKUP_GOVERNANCE.md](BACKUP_GOVERNANCE.md) | Backup governance |
| [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) | Device naming, Tailscale IPs |
| [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md) | Shop infrastructure |
| [MACBOOK_SSOT.md](MACBOOK_SSOT.md) | Workstation (connects to minilab) |
| [SSOT_UPDATE_TEMPLATE.md](SSOT_UPDATE_TEMPLATE.md) | How to update this document |
