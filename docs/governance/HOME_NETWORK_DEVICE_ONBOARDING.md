---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: home-network
---

# Home Network Device Onboarding (Canonical Runbook)

## Goal

Every new device on the home network must follow the same spine-native workflow so agents always know what the device is, where it is, how to reach it, and where credentials live.

## Definitions

- **Canonical ID**: short, stable `id` (kebab-case), used across bindings + SSOTs. Example: `beelink`, `nas`, `slzb-06`, `ha`.
- **LAN-only**: device has no Tailscale and may not support SSH. Must still appear in `ssh.targets.yaml` with `access_method: lan_only` and `probe_via: proxmox-home`.

## IP Policy

| Field | Value |
|-------|-------|
| Subnet | 10.0.0.0/24 |
| Gateway | 10.0.0.1 (UDR7) |
| DHCP Range | 10.0.0.200-254 |
| DNS | 10.0.0.1 (UDR itself, NOT pihole-home) |
| WiFi SSID | pogodobby |

**Rule:** prefer DHCP reservations on UDR7 for stability. Use true static only when required.

## Current Device Map

| Device | IP | Tailscale | Role |
|--------|----|-----------|------|
| UDR7 gateway | 10.0.0.1 | — | Router, WiFi AP, DHCP |
| Beelink (proxmox-home) | 10.0.0.179 | 100.103.99.62 | Hypervisor |
| SLZB-06 | 10.0.0.51 | — | Zigbee coordinator |
| SLZB-06MU | 10.0.0.52 | — | Zigbee + Matter |
| pihole-home (LXC 105) | 10.0.0.53 | 100.105.148.96 | DNS (stopped) |
| download-home (LXC 103) | 10.0.0.101 | 100.125.138.110 | *arr stack (stopped) |
| homeassistant (VM 100) | 10.0.0.100 | 100.67.120.1 | Home automation |
| vaultwarden (VM 102) | 10.0.0.102 | 100.93.142.63 | Password manager |
| Synology NAS | 10.0.0.150 | 100.102.199.111 | Storage |
| TubesZB | 10.0.0.90 | — | Z-Wave coordinator |

## Onboarding Checklist

### 1. Pick Canonical ID
- Format: `<type>-<detail>` (kebab-case)
- No site suffix needed for home devices

### 2. Assign Stable IP
- Choose IP in 10.0.0.0/24 (outside DHCP range .200-.254)
- Set DHCP reservation on UDR7 for the device MAC

### 3. Store Credentials
- Infisical path: `infrastructure/prod:/spine/home/<category>/<id>/*`
- Never write passwords into git

### 4. Update Bindings
- `ops/bindings/ssh.targets.yaml` (SSH or LAN-only entry)
- `ops/bindings/services.health.yaml` (if device has HTTP endpoint)

### 5. Update SSOTs
- `docs/governance/MINILAB_SSOT.md` (network map, device details)
- `docs/governance/DEVICE_IDENTITY_SSOT.md` (device identity)

### 6. Verify
- Confirm IP reachability from proxmox-home
- Run `./bin/ops cap run spine.verify`

## Device-Specific Notes

### New VM/LXC on proxmox-home
Required: id, hostname, VMID, Tailscale IP, LAN IP, purpose, RAM, disk, services, NFS mounts.

### Zigbee/Z-Wave Coordinator
Required: id, model, MAC, management IP, web UI URL, firmware version, protocol, HA integration.

### NAS Share/Export
Required: export path, mount point, consuming VMs, fstab entry.

## Known Constraints

- **Pi-hole NOT used for DNS**: UDR7 handles DNS directly at 10.0.0.1
- **NAS hostname**: Add `100.102.199.111 nas` to `/etc/hosts` on VMs needing hostname resolution
- **proxmox-home hostname**: Actual hostname is `pve` (exception policy). Use Tailscale hostname `proxmox-home` for SSH

## Related Documents

- [MINILAB_SSOT.md](MINILAB_SSOT.md)
- [HOME_NETWORK_AUDIT_RUNBOOK.md](HOME_NETWORK_AUDIT_RUNBOOK.md)
- [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md)
- [SHOP_NETWORK_DEVICE_ONBOARDING.md](SHOP_NETWORK_DEVICE_ONBOARDING.md)
