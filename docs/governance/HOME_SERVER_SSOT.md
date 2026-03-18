---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-12
verification_method: home inventory parity + live proxmox/synology read-only checks
scope: home-control-plane-summary
---

# HOME SERVER SSOT

This is the spine-facing summary for the home rack and home-managed endpoints.

Authority boundary:
- Canonical home domain contract lives in `ops/bindings/home.authority.contract.yaml`.
- Detailed device/runtime/network/storage inventories live in the `ops/bindings/home.*` bindings plus `ops/bindings/synology918.storage.manifest.yaml`.
- This doc keeps the boring target model, generated projections, and current closure blockers in one governed surface.

## Managed Home Endpoints

| Class | Device | Canonical IP | Access Model | Notes |
|-------|--------|--------------|--------------|-------|
| Gateway | `udr-home` | `10.0.0.1` | LAN-only via proxmox relay | UniFi Dream Router 7 |
| Switch | `usw-flex-2-5g-5` | `10.0.0.102` | LAN-only | Home aggregation switch |
| Switch | `usw-lite-16-poe` | `10.0.0.211` | LAN-only | Primary PoE access switch |
| Hypervisor | `proxmox-home` | `10.0.0.179` / `100.103.99.62` | Tailscale | Beelink SER7 home hypervisor |
| NAS | `synology918` | `10.0.0.150` / `100.102.199.111` | LAN + Tailscale | Canonical home backup and personal-data appliance |
| Home Assistant | `ha` | `10.0.0.100` / `100.67.120.1` | LAN + Tailscale | Primary home automation runtime |
| Pi-hole | `pihole-home` | `10.0.0.53` / `100.105.148.96` | LAN + Tailscale | Home-local DNS filtering |
| Zigbee coordinator | `slzb-06` | `10.0.0.51` | LAN-only | Primary Zigbee coordinator |
| Thread coordinator | `slzb-06mu` | `10.0.0.52` | LAN-only | Matter/Thread border router |
| Z-Wave coordinator | `tubeszb-2026-zw` | `10.0.0.90` | LAN-only | Primary Z-Wave coordinator |

## Canonical Home Target Model

| Plane | Canonical surface | Boring target |
|-------|-------------------|---------------|
| Substrate | `ops/bindings/home.hardware.inventory.yaml` + `ops/bindings/home.proxmox.inventory.yaml` | `proxmox-home` is the only home hypervisor. |
| Storage | `ops/bindings/home.storage.map.yaml` + `ops/bindings/synology918.storage.manifest.yaml` | `local-lvm` = hot runtime boot disks, Synology `/volume1/backups/proxmox_backups/dump` = canonical home VM/LXC backup lane, Synology `/volume1` = canonical home personal-data lane. |
| Runtime | `ops/bindings/home.proxmox.inventory.yaml` | Every kept home workload is a named VM/LXC; decommissioned guests are explicit tombstones. |
| Network | `ops/bindings/home.unifi.network.inventory.yaml` + `ops/bindings/network.dns.local.registry.yaml` | One LAN truth, one local DNS truth, and one Tailscale access path per kept node. |
| Ingress | `ops/bindings/home.ingress.map.yaml` + `ops/bindings/domain.routing.registry.yaml` | Public home ingress is minimal and intentional; LAN ingress uses `.mint.local`; remote private ingress uses Tailscale or proxmox relay. |
| Backup | `ops/bindings/backup.inventory.yaml` + `ops/bindings/synology918.storage.manifest.yaml` | Home runtime backups land on Synology; no second-environment cold plane is currently declared for home personal data. |
| Tombstones | `ops/bindings/home.proxmox.inventory.yaml` + `ops/bindings/estate.surface.register.yaml` | Decommissioned home guests are explicit non-runtime surfaces. |

## Generated Projections

- Storage authority projection: `ops/bindings/home.storage.map.yaml`
- Home media residue inventory: `ops/bindings/home.media.residue.inventory.yaml`
- Media lifecycle contract: `ops/bindings/media.lifecycle.contract.yaml`
- Media data execution gate: `ops/bindings/media.data.lifecycle.execution.yaml`
- Ingress authority projection: `ops/bindings/home.ingress.map.yaml`
- Rack scorecard: `docs/reference/generated/HOME_RACK_SCORECARD.md`
- Estate closure scorecard: `docs/reference/generated/ESTATE_BORINGNESS_SCORECARD.md`
- Rebuild command: `./bin/ops cap run infra.estate.boringness.build`

## Current Media Recovery State

- `media-home` is in `jellyfin_only_recovery` while the data-side boringness pass remains active.
- The authoritative residue baseline is `ops/bindings/home.media.residue.inventory.yaml`.
- The authoritative lifecycle doctrine is `ops/bindings/media.lifecycle.contract.yaml`.
- The restart gate is `ops/bindings/media.data.lifecycle.execution.yaml`, enforced by `./bin/ops cap run media.data.readiness.verify`.
- Full media-home restarts are intentionally blocked while transit residue still acts like storage.

## Current Tombstones

| Tombstone | Runtime posture | Restore posture | Notes |
|-----------|-----------------|-----------------|-------|
| `vaultwarden` / VM 102 | Not runtime. Superseded by `infra-core` at the shop site. | Historical backup residue may still exist on Synology; not canonical runtime. | Decommissioned `2026-02-16`. |
| `immich-home` / VM 101 | Not runtime. | No active restore path declared in home runtime authority. | Stopped/decommissioned. |
| `download-home` / LXC 103 | Not runtime. | No active restore path declared in home runtime authority. | Soft-decommissioned `2026-02-21`. |

## Verification

```bash
./bin/ops cap run infra.estate.boringness.build -- --check
./bin/ops cap run home.vm.status
./bin/ops cap run home.backup.status
./bin/ops cap run media.data.readiness.verify
```
