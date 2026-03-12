---
status: generated
owner: "@ronny"
last_verified: 2026-03-12
scope: home-rack-scorecard
source_binding: ops/bindings/home.storage.map.yaml
---

# Home Rack Scorecard

- Generated: `2026-03-12T04:03:46Z`
- Rebuild: `./bin/ops cap run infra.estate.boringness.build`
- Active runtimes: `2`
- Tombstones: `3`
- Public routes: `1`

## Substrate

| Plane | Canonical surface | Current truth |
| --- | --- | --- |
| Hypervisor | `ops/bindings/home.proxmox.inventory.yaml` | `proxmox-home` is the only home hypervisor. |
| Storage map | `ops/bindings/home.storage.map.yaml` | Runtime, backup, and personal-data storage truth are projected from authoritative bindings plus live proof. |
| Ingress | `ops/bindings/home.ingress.map.yaml` | Public, local-DNS, and Tailscale ingress lanes are explicit. |

## Storage Tiers

| Tier | Plane | Purpose | Layout |
| --- | --- | --- | --- |
| home-local-lvm | hot_runtime | Primary local-lvm runtime backing for proxmox-home guest boot/root disks. | single-host NVMe + lvmthin |
| synology-home-backup | warm_backup | Canonical home backup lane for proxmox-home VM/LXC artifacts. | Synology volume1 share exported to proxmox-home as synology-backups |
| synology-home-data | warm_payload | Canonical home personal data and media lane. | Synology volume1 |

## Active Runtime Units

| VMID | Runtime | Kind | Startup | Tier | Durable State | Backup Lane | Ingress |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 100 | homeassistant | vm | auto | home-local-lvm | local-lvm:vm-100-disk-1, local-lvm:vm-100-disk-0 | nas-home-local-exception | ha.ronny.works |
| 105 | pihole-home | lxc | auto | home-local-lvm | local-lvm:vm-105-disk-0 | nas-home-local-exception | private-only |

## Tombstones

| VMID | Runtime | Status | Note |
| --- | --- | --- | --- |
| 101 | vm-101-immich-home | stopped | Historical home guest retained only as decommissioned inventory. |
| 102 | vaultwarden | stopped | Legacy Vaultwarden (superseded by infra-core) |
| 103 | lxc-103-download-home | stopped | Historical home guest retained only as decommissioned inventory. |

## Current Risks

- No declared second-environment cold/offsite restore plane exists for home personal data on Synology.
- Home switch ports 3/4/6 still rely on inferred endpoint identity instead of traced physical truth.
- Synology mint-os residue remains as non-canonical historical hold.
