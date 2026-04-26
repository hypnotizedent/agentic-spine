---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
verification_method: live-system-inspection
scope: home-control-plane-summary
---

# MINILAB SSOT

This is the spine-facing summary for the home minilab infrastructure.

Authority boundary:
- Canonical identity and network naming live in `docs/governance/DEVICE_IDENTITY_SSOT.md`.
- Detailed home hardware specs, RAID configs, NFS exports, backup schedules, and operator runbooks live in `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/home/MINILAB_SSOT.md`.
- This spine doc keeps agent facts and home control-plane parity attached to a real governed surface.

## Home Infrastructure Summary

| Class | Device | Canonical IP | Access Model | Notes |
|-------|--------|--------------|--------------|-------|
| Hypervisor | `proxmox-home` | `100.103.99.62` | Tailscale | Beelink SER7, Proxmox VE 8.4.1 |
| NAS | `nas` | `100.102.199.111` | Tailscale | Synology DS918+, 20TB SHR + NVMe cache |
| Home Assistant | `ha` | `100.67.120.1` | Tailscale | VM 100 on proxmox-home |
| DNS | `pihole-home` | `100.105.148.96` | Tailscale | LXC 105 on proxmox-home |
| Media | `media-home` | `100.113.72.41` | Tailscale | VM 106 on proxmox-home |

## VM/LXC Inventory

| VMID | Hostname | Status | Purpose |
|------|----------|--------|---------|
| 100 | homeassistant | Running | Home automation |
| 101 | immich | Destroyed | Shop VM 203 is canonical |
| 102 | vaultwarden | Decommissioned | Superseded by infra-core VM 204 |
| 105 | pihole-home | Running | Home DNS filtering |
| 106 | media-home | Running | Canonical home media plane |

## Storage

| Target | Path | Status |
|--------|------|--------|
| Proxmox vzdump | `/volume1/backups/proxmox_backups` | Active (2 jobs enabled) |
| NFS homelab | `/volume1/homelab` | Mounted on proxmox-home |

## Verification

```bash
ssh proxmox-home "qm list && pct list"
ping -c1 nas pihole-home ha
ssh media-home docker ps
```
