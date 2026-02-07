---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-06
verification_method: receipt + on-site audit
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
| **Proxmox Version** | 9.0.3 | 2026-01-21 |
| **Kernel** | 6.14.8-2-pve | 2026-01-21 |
| **Drive Bays** | TBD (2.5" or 3.5" - requires physical audit) | - |
| **Controller/HBA** | TBD (verify before purchasing drives) | - |

### ZFS Storage Pools

| Pool | Size | Allocated | Free | Capacity | Health | Verified |
|------|------|-----------|------|----------|--------|----------|
| **media** | 29.1T | 13.1T | 16.0T | 45% | ONLINE | 2026-01-21 |
| **tank** | 29.1T | 6.14T | 23.0T | 21% | ONLINE | 2026-01-21 |

**tank datasets:**
- `tank/docker`: 379GB
- `tank/backups`: 92GB
- `tank/immich/photos`: 1.2TB

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

**Source:** External schedule inventory (workbench tooling via `WORKBENCH_TOOLING_INDEX.md`).

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
