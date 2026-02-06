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

### Hardware Compatibility Notes (High Level)

- **R730XD:** verify whether bays are 2.5" or 3.5" and which controller/HBA is installed before purchasing drives.
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
| `OL_SHOP_BASELINE_FINISH` | Finish remaining on-site inventory: MD1400 drive list, camera location map, AP settings, cron/backup schedules. |

---

## Evidence / Receipts

- `receipts/sessions/DELL_N2024P_FACTORY_RESET_20260205_122838/receipt.md`

---

## Related Documents

- [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md)
- [MINILAB_SSOT.md](MINILAB_SSOT.md)
- [MACBOOK_SSOT.md](MACBOOK_SSOT.md)
- [SECRETS_POLICY.md](SECRETS_POLICY.md)
- [SSOT_UPDATE_TEMPLATE.md](SSOT_UPDATE_TEMPLATE.md)
