---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-07
verification_method: receipt + on-site audit + live-ssh-inspection
scope: shop-infrastructure
parent_receipts:
  - "DELL_N2024P_FACTORY_RESET_20260205_122838"
---

# SHOP SERVER SSOT

> Canonical, spine-native description of the **Shop rack**.
>
> **Covers:** Dell R730XD (`pve`), MD1400 DAS, Dell N2024P switch, NVR/cameras, UPS, and the Shop LAN.
>
> **Authority boundary:**
> - Hostnames/IPs: [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) (canonical)
> - Hardware/topology/ops procedures: this doc (canonical within `shop-infrastructure`)
>
> **No secrets rule:** Credentials, RTSP URLs, WiFi SSIDs, and passwords must be stored in Infisical. This repo never contains secret values.

---

## Quick Reference (No Secrets)

| Component | Canonical Name | Access | Credentials (Infisical) |
|----------|-----------------|--------|--------------------------|
| Proxmox host | `pve` | `ssh pve` or `https://pve:8006` | `infrastructure/prod:/spine/shop/pve/*` |
| iDRAC | `idrac-shop` | `https://192.168.12.250` | `infrastructure/prod:/spine/shop/idrac/*` |
| Switch | `switch-shop` (Dell N2024P) | `http://192.168.12.1` | `infrastructure/prod:/spine/shop/switch/*` |
| NVR | `nvr-shop` | `http://192.168.12.216` | `infrastructure/prod:/spine/shop/nvr/*` |
| WiFi AP | `ap-shop` (EAP225) | `http://192.168.12.249` | `infrastructure/prod:/spine/shop/wifi/*` |

Notes:
- If an IP above ever conflicts with [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md), treat this table as stale and update it.
- If a service is reachable only by LAN IP, it is **not** a Tier-1 dependency (Tailscale is the control plane).

---

## Physical Infrastructure

### Rack Inventory (Minimum Baseline)

| Component | Model | Role | Verified |
|----------|-------|------|----------|
| Server | Dell PowerEdge R730XD | Shop hypervisor (`pve`) | partial |
| DAS | Dell MD1400 | Bulk storage shelf | unverified |
| Switch | Dell N2024P | Shop LAN switching / gateway | verified |
| UPS | APC (model TBD) | Power protection | unverified |
| NVR | Hikvision (model TBD) | Camera recorder | partial |
| WiFi AP | TP-Link EAP225 | Shop WiFi | partial |

### R730XD Hardware Specifications

| Component | Value | Verified |
|-----------|-------|----------|
| **Model** | Dell PowerEdge R730XD | 2026-01-21 |
| **CPU** | 2x Intel Xeon E5-2640 v3 (32 threads total) | 2026-01-21 |
| **RAM** | 188GB | 2026-01-21 |
| **Proxmox Version** | 9.1.4 | 2026-02-07 |
| **Kernel** | 6.14.8-2-pve | 2026-02-07 |
| **Boot Drives** | 2x Seagate ST9500620SS 500GB SAS 2.5" | 2026-02-07 |
| **Drive Bays** | TBD (2.5" or 3.5" - requires physical audit) | - |
| **Controller/HBA** | TBD (verify before purchasing drives) | - |

### ZFS Storage Pools

| Pool | Size | Allocated | Free | Capacity | Health | Verified |
|------|------|-----------|------|----------|--------|----------|
| **media** | 29.1T | 16.7T | 12.4T | 57% | ONLINE | 2026-02-07 |
| **tank** | 29.1T | 7.35T | 21.8T | 25% | ONLINE | 2026-02-07 |

**media pool:** RAIDZ1, 4x Seagate ST8000AS0002 8TB (Archive/SMR drives)
- Serials: Z840A33Q, Z840A22Z, Z840A33F, Z840AAFE
- **WARNING:** SMR drives are suboptimal for ZFS. Monitor for performance degradation.
- Last scrub: CANCELED on 2026-01-11 (should be investigated)

**tank pool:** RAIDZ2, 8x Seagate ST4000NM0063 4TB (Constellation ES.3, enterprise SAS)
- Last scrub: 2026-02-01, 0 errors

**tank datasets (2026-02-07):**
- `tank/docker`: 567GB (was 379GB on 2026-01-21)
- `tank/docker/media-stack`: 24.1GB
- `tank/docker/databases`: 208K
- `tank/backups`: 3.5TB (was 92GB — vzdump growing)
- `tank/immich/photos`: 1.2TB
- `tank/vms`: 256K

### VM Inventory (2026-02-07)

| VMID | Name | Status | RAM | Boot Disk | Notes |
|------|------|--------|-----|-----------|-------|
| 200 | docker-host | running | 96GB | 300GB | Mint OS production |
| 201 | media-stack | running | 16GB | 80GB | Jellyfin + *arr |
| 202 | automation-stack | running | 16GB | 100GB | n8n + Ollama |
| 203 | immich | running | 16GB | 50GB | Shop photos (Tailscale: immich-1) |
| 204 | infra-core | running | 8GB | 50GB | Core infra |
| 9000 | template | stopped | 2GB | 3.5GB | Ubuntu 24.04 cloud-init |

**NOTE:** VM 204 (infra-core) is NOT in the vzdump backup job. Add it.

### NFS Exports from PVE

| Export | Client | Purpose |
|--------|--------|---------|
| `/tank/docker` | docker-host (100.92.156.118) | Docker volumes |
| `/tank/backups` | docker-host (100.92.156.118) | Backup target |
| `/tank/vms` | docker-host (100.92.156.118) | VM storage |
| `/tank/docker/media-stack` | media-stack (100.117.1.53) | Container config/volumes |
| `/media` | media-stack (100.117.1.53) | Media files |
| `/mnt/easystore/backups` | docker-host (100.92.156.118) | Easystore backup mount |

All exports use `rw,sync,no_root_squash` over Tailscale IPs.

### Hardware Compatibility Notes

- **R730XD:** Verify bay type (2.5" or 3.5") before purchasing drives.
- **MD1400:** 12-bay 3.5" shelf (verify actual population + drive models).

---

## Network (Shop)

### Subnet

| Item | Value |
|------|-------|
| Subnet | `192.168.12.0/24` |
| Gateway | `192.168.12.1` (`switch-shop` / Dell N2024P) |

### Camera Network

Cameras are intentionally isolated.

Baseline truth:
- NVR is reachable on Shop LAN (`nvr-shop`).
- Camera endpoints/RTSP URLs are treated as secrets and must be stored in Infisical.

---

## Virtualization / Workloads (Shop)

### Proxmox Host: `pve`

This is the Shop hypervisor. Core VM inventory (foundational scope):

| VM | Purpose | Foundational Scope |
|----|---------|--------------------|
| `docker-host` | Production docker workloads | yes |
| `automation-stack` | Automation / n8n / misc | yes |
| `media-stack` | Media stack | deferred |
| `immich-1` | Photos | deferred |

If you need to make a placement decision ("where should this run?"):
1. Read [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) for the Tier table.
2. Use this doc for capacity/constraints (hardware + what already runs here).
3. If still unclear, open a mailroom item and create/attach an open loop.

---

## Scheduled Tasks (pve)

| Schedule | Command | Purpose | Status |
|----------|---------|---------|--------|
| `0 2 * * *` | `/usr/local/bin/zfs-snapshot.sh` | Daily ZFS snapshot of root datasets | ACTIVE |
| `0 3 * * 0` | `zpool scrub tank` | Weekly scrub of tank pool | ACTIVE |
| `02:00 daily` | vzdump VMs 200-203 | Snapshot backup to tank-backups (zstd, max 2) | ACTIVE |

**Source:** crontab (`crontab -l`) and `/etc/pve/jobs.cfg`.

**Known issues:**
- VM 204 (infra-core) is NOT included in the vzdump backup job.
- Media pool scrub was CANCELED on 2026-01-11 — no cron job for media scrub.
- No `zpool scrub media` in cron — only `tank` is scrubbed.

---

## Verification Commands (Safe)

Run from the MacBook (over Tailscale):

```bash
# Tier 1 reachability
for host in pve docker-host proxmox-home; do
  echo "=== $host ==="
  ssh -o ConnectTimeout=5 $host uptime 2>/dev/null || echo "UNREACHABLE"
done

# Proxmox version / health (shop)
ssh pve 'pveversion -v | head -5'
ssh pve 'pvesm status'
```

---

## Open Loop

This SSOT intentionally keeps **one** loop for unfinished physical audits to prevent loop sprawl.

| Loop ID | Meaning |
|--------|---------|
| `OL_SHOP_BASELINE_FINISH` | Finish remaining on-site inventory: MD1400 drive list, R730XD bay type, camera location map, AP settings. |

**UNVERIFIED (requires physical audit):**
- MD1400 DAS: Drive models, population, health
- R730XD: Bay type (2.5" vs 3.5"), controller/HBA model
- Camera network: Camera count, locations, RTSP endpoints (secrets in Infisical)
- WiFi AP (EAP225): Configuration, SSID → `infrastructure/prod:/spine/shop/wifi/*`
- UPS: Model confirmation, capacity, runtime

---

## Evidence / Receipts

- `receipts/sessions/DELL_N2024P_FACTORY_RESET_20260205_122838/receipt.md`

---

## Open Network Tasks (shop)

- [ ] T-Mobile GAR4 at 192.168.12.1 still pointing DHCP DNS to 192.168.12.191 (docker-host); update it to 192.168.12.204 (infra-core) before hauling more services off docker-host.

---

## Related Documents

- [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md)
- [MINILAB_SSOT.md](MINILAB_SSOT.md)
- [MACBOOK_SSOT.md](MACBOOK_SSOT.md)
- [SECRETS_POLICY.md](SECRETS_POLICY.md)
- [SSOT_UPDATE_TEMPLATE.md](SSOT_UPDATE_TEMPLATE.md)
