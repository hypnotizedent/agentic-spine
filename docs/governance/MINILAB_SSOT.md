---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
verification_method: receipt-consolidation
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
> **Last Verified:** February 5, 2026 (partial - based on 2026-01-21 discovery)

---

## Quick Reference

| System | IP | Access |
|--------|-----|--------|
| proxmox-home | 100.103.99.62 | `ssh root@proxmox-home` |
| NAS (Synology) | 100.102.199.111 | https://nas:5001 |
| Home Assistant | 100.67.120.1 | http://ha:8123 |
| Vaultwarden | 100.93.142.63 | http://vault:8080 |
| Pi-hole | 100.105.148.96 | http://pihole-home/admin |

---

## Beelink Mini PC (proxmox-home)

### Hardware Specifications

| Component | Specification | Verified |
|-----------|---------------|----------|
| **Model** | Beelink Mini S12 Pro | - |
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
| Local | 10.0.0.50 | Home LAN |
| Gateway | 10.0.0.1 | Ubiquiti UDR |

### Resource Usage (2026-01-21)

| Metric | Value |
|--------|-------|
| Load Average | 0.22, 0.30, 0.28 |
| RAM Free | ~447MB |
| Root FS | 11GB used / 94GB total (13%) |

---

## Synology DS918+ NAS

### Hardware Specifications

| Component | Specification |
|-----------|---------------|
| **Model** | Synology DS918+ |
| **CPU** | Intel Celeron J3455 (4 cores) |
| **RAM** | 4GB (expandable to 8GB) |
| **Drive Bays** | 4x 3.5" SATA |
| **Network** | 2x 1GbE (link aggregation capable) |

### Network Configuration

| Interface | IP | Notes |
|-----------|-----|-------|
| Tailscale | 100.102.199.111 | `nas` hostname |
| Local | 10.0.0.150 | Home LAN |
| DSM Web UI | https://10.0.0.150:5001 | - |

### Storage Volumes

> **OPEN LOOP:** `OL_HOME_BASELINE_FINISH` — Finish baseline inventory (NAS + backups + cron + SSH access)

| Volume | Capacity | Used | Purpose |
|--------|----------|------|---------|
| volume1 | ~20TB | 7.1TB (37%) | Primary storage |

### NFS Exports

| Export Path | Mount Point | Consumers |
|-------------|-------------|-----------|
| /volume1/homelab | /mnt/pve/synology918 | proxmox-home |
| /volume1/backups/proxmox_backups | /mnt/pve/synology-backups | proxmox-home |
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
| 101 | immich | 100.83.160.109 | 16GB | 80GB | Running |
| 102 | vaultwarden | 100.93.142.63 | 2GB | 16GB | Running |

### LXC Containers

| VMID | Hostname | Tailscale IP | Status | Purpose |
|------|----------|--------------|--------|---------|
| 103 | download-home | 100.125.138.110 | Running | *arr stack (home) |
| 105 | pihole-home | 100.105.148.96 | Running | DNS + ad-blocking |

### VM Details

#### VM 100: Home Assistant

| Field | Value |
|-------|-------|
| Tailscale IP | 100.67.120.1 |
| Local IP | 10.0.0.102 |
| Web UI | http://ha:8123 |
| Purpose | Home automation hub |
| Integrations | Zigbee (SLZB-06), Z-Wave (TubesZB), UniFi |

#### VM 101: Immich (Home)

| Field | Value |
|-------|-------|
| Tailscale IP | 100.83.160.109 |
| Storage | NAS NFS mount (/volume1/im2ch) |
| Web UI | http://immich-home:2283 |
| Purpose | Photo management (home instance) |

**Containers:**
- immich_server
- immich_machine_learning
- immich_postgres
- immich_redis
- immich_node_exporter

#### VM 102: Vaultwarden

| Field | Value |
|-------|-------|
| Tailscale IP | 100.93.142.63 |
| Web UI | http://vault:8080 |
| Purpose | Password manager (Bitwarden-compatible) |

**Container:** vaultwarden (healthy)

#### LXC 103: download-home

| Field | Value |
|-------|-------|
| Tailscale IP | 100.125.138.110 |
| Purpose | *arr stack for home media |
| Note | SSH access requires key setup |

#### LXC 105: pihole-home

| Field | Value |
|-------|-------|
| Tailscale IP | 100.105.148.96 |
| Purpose | DNS server + ad-blocking |
| Status | FTL listening on port 53 (verified) |

---

## Home Network Summary (10.0.0.0/24)

### IP Address Map

| Device | Local IP | Tailscale IP | Role |
|--------|----------|--------------|------|
| Ubiquiti UDR | 10.0.0.1 | - | Gateway, WiFi AP, DHCP |
| Synology NAS | 10.0.0.150 | 100.102.199.111 | Storage |
| proxmox-home | 10.0.0.50 | 100.103.99.62 | Hypervisor |
| SLZB-06 (Zigbee) | 10.0.0.51 | - | Zigbee coordinator |
| SLZB-06MU (Matter) | 10.0.0.52 | - | Zigbee + Matter |
| TubesZB (Z-Wave) | 10.0.0.217 | - | Z-Wave coordinator |
| homeassistant | 10.0.0.102 | 100.67.120.1 | VM 100 |
| pihole-home | 10.0.0.100 | 100.105.148.96 | LXC 105 |
| download-home | 10.0.0.101 | 100.125.138.110 | LXC 103 |

### Network Configuration

| Setting | Value |
|---------|-------|
| Subnet | 10.0.0.0/24 |
| Gateway | 10.0.0.1 (UDR) |
| DHCP Range | 10.0.0.200 - 10.0.0.254 |
| DNS | 1.1.1.1, 8.8.8.8 (or pihole-home) |
| WiFi SSID | pogodobby |

### Radio Coordinators

| Device | Model | IP | Protocol | Status |
|--------|-------|----|----------|--------|
| SLZB-06 | SMLIGHT SLZB-06 | 10.0.0.51 | Zigbee (CC2652P) | Online |
| SLZB-06MU | SMLIGHT SLZB-06MU | 10.0.0.52 | Zigbee + Matter | Online |
| TubesZB | TubesZB Z-Wave | 10.0.0.217 | Z-Wave | Online |

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
```

### Disk Usage

| Filesystem | Size | Used | Avail | Mount |
|------------|------|------|-------|-------|
| /dev/mapper/pve-root | 94GB | 11GB | 79GB | / |
| synology-backups | 20TB | 7.1TB | 13TB | /mnt/pve/synology-backups |

---

## Backup Configuration

### Proxmox vzdump

| Target | Schedule | Retention | Destination |
|--------|----------|-----------|-------------|
| VMs 100-102 | Daily | 7 days | synology-backups NFS |
| LXCs 103, 105 | Daily | 7 days | synology-backups NFS |

### NAS Backups

**Backup Targets on NAS:**

| Target | Path | Consumers | Retention |
|--------|------|-----------|-----------|
| Proxmox vzdump | `/volume1/backups/proxmox_backups` | proxmox-home vzdump | 7 days |
| Mint-OS PostgreSQL | `/volume1/backups/mint-os/postgres/` | docker-host | daily |
| Mint-OS configs | `/volume1/backups/mint-os/configs/` | docker-host | as-needed |
| Home Assistant | `/volume1/backups/homeassistant_backups/` | VM 100 | manual |

**Storage Summary (NAS_INVENTORY.md):**

| Volume | Total | Used | Purpose |
|--------|-------|------|---------|
| volume1 | 20TB | ~8.7TB (43%) | Primary storage |

**Source:** NAS_INVENTORY.md, HOME_INFRASTRUCTURE_AUDIT.md

---

## Compatibility Hints

### Workload Recommendations

| Workload | Recommended Host | Reason |
|----------|------------------|--------|
| Frigate NVR | proxmox-home | Has iGPU for video decode |
| Photo ML | immich (VM 101) | Already has ML container |
| Heavy DB | NAS + SSD cache | NAS has caching capability |
| Pi-hole secondary | download-home LXC | Low resource, always on |

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

# Pi-hole status
ssh pihole-home "pihole status"

# Vaultwarden
curl -s http://vault:8080/
```

---

## Cronjobs / Scheduled Tasks

### proxmox-home (root)

> **Note:** As of 2026-01-21, `crontab -l` returns `no crontab for root`. Backup and transfer jobs need to be re-created.

**Planned (not yet enabled):**

| Schedule | Script | Purpose | Status |
|----------|--------|---------|--------|
| `30 3 * * *` | `backup-ha.sh` | Home Assistant backup | PENDING |
| `0 3 * * *` | `backup-immich-db.sh` | Immich DB backup | PENDING |
| `0 5 * * 0` | `backup-immich-library.sh` | Immich library (weekly) | PENDING |
| `*/5 * * * *` | `transfer-to-remote.sh` | Rsync staging to remote | PENDING |

### System-Managed Schedules

| System | Schedule | Task | Status |
|--------|----------|------|--------|
| Proxmox vzdump | Daily | VM/LXC backup to synology-backups | ACTIVE (via GUI) |
| Synology DSM | Weekly | RAID scrub | ACTIVE |
| Pi-hole | Weekly | Gravity update | ACTIVE |

**Source:** External schedule inventory (workbench tooling via `WORKBENCH_TOOLING_INDEX.md`).

---

## Known Issues

| Issue | Status | Notes |
|-------|--------|-------|
| download-home SSH | OPEN | Permission denied - needs key setup |
| Immich home vs shop | INFO | Two instances - may consolidate |
| RAM pressure | INFO | 27GB shared across 5 VMs/LXCs |

---

## Open Loops

| Loop ID | Description | Priority |
|---------|-------------|----------|
| `OL_HOME_BASELINE_FINISH` | Finish baseline: enable proxmox-home crons, fix download-home SSH | MEDIUM |

**UNVERIFIED (requires live action):**
- proxmox-home crontab: Currently empty, crons need to be re-created
- download-home SSH: Permission denied, needs key setup
- NAS SSH access: Requires key configuration or Tailscale SSH
- Proxmox backup job status: GUI says disabled but backups exist

---

## Evidence / Receipts

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
| [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) | Device naming, Tailscale IPs |
| [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md) | Shop infrastructure |
| [MACBOOK_SSOT.md](MACBOOK_SSOT.md) | Workstation (connects to minilab) |
| [SSOT_UPDATE_TEMPLATE.md](SSOT_UPDATE_TEMPLATE.md) | How to update this document |
