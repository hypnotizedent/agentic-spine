---
status: generated
owner: "@operator"
last_verified: 2026-04-09
scope: shop-rack-scorecard
source_binding: ops/bindings/shop.storage.map.yaml
---

# Shop Rack Scorecard

- Generated: `2026-04-09T14:35:07Z`
- Rebuild: `./bin/ops cap run infra.shop.storage.authority.build`
- Active runtimes: `12`
- Tombstones: `1`
- Public runtimes: `8`

## Substrate

| Plane | Canonical surface | Current truth |
| --- | --- | --- |
| Hypervisor | `ops/bindings/hardware.inventory.yaml` | `pve` is the only shop hypervisor. |
| Storage map | `ops/bindings/shop.storage.map.yaml` | Runtime, backup, and tombstone storage truth are projected from authoritative bindings. |
| Ingress | `ops/bindings/shop.ingress.map.yaml` + `ops/bindings/services.health.yaml` | Public reachability is derived from the runtime ingress authority plus active health surfaces. |

## Storage Tiers

| Tier | Plane | Purpose | Layout | Backing |
| --- | --- | --- | --- | --- |
| tank | hot_runtime | Primary hot VM/app/runtime pool on pve. | RAIDZ2 | sda-sdh |
| media | warm_payload | Media payload only or phased-out pressure lane. | RAIDZ1 | sdi-sdl |
| nas-primary | cold_backup_archive_stage | Cold backup/archive/staging shelf for the shop environment. | RAIDZ2 (12 drives) | 12 physical drives |

## Media Pressure

- Observed: `unknown`
- media: `unknown used`, `unknown free`, `unknown%`
- nas-primary: `unknown used`, `unknown free`, `unknown%`
- Canonical payload: `unknown`
- Regenerable runtime pressure: `unknown`
- View truth: none

| Path | Surface Class | Reclaim Class | Usage | Purpose |
| --- | --- | --- | --- | --- |

| Lane | Status | Target | Current Size | Rationale |
| --- | --- | --- | --- | --- |

## Active Runtime Units

| VMID | Runtime | Kind | Startup | Tier | Durable State | Backup Lane | Ingress | Monitoring |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 202 | automation-stack | vm | auto | data-vms | boot-disk:data-vms:vm-202-disk-0, data-vms:pve:data/vms/vm-202-disk-0 (ZFS zvol, 100G), tank:tank-vms:vm-202-disk-0, +2 more | pve-vzdump-primary, server-primary-infra-core-backups | chat.example.com, n8n.example.com | 4 probes |
| 203 | immich | vm | auto | tank-docker | tank:tank/immich, tank:pve:tank/immich | pve-vzdump-primary | photos.example.com | 2 probes |
| 204 | infra-core | vm | auto | boot-only | boot-disk:local-lvm:vm-204-disk-0, local-lvm:vm-204-cloudinit, boot-disk:/opt/stacks | pve-vzdump-primary, server-primary-infra-core-backups | auth.example.com, pihole.example.com, vault.example.com | 6 probes |
| 205 | observability | vm | auto | boot-only | boot-disk:local-lvm:vm-205-disk-0, local-lvm:vm-205-cloudinit, boot-disk:/opt/stacks | pve-vzdump-primary | dash.example.com, grafana.example.com | 6 probes, node-exporter |
| 206 | dev-tools | vm | auto | boot-only | boot-disk:local-lvm:vm-206-disk-0, local-lvm:vm-206-cloudinit, boot-disk:/opt/stacks/gitea | pve-vzdump-primary, server-primary-dev-tools-backups | git.example.com | 1 probes |
| 207 | ai-consolidation | vm | auto | boot-only | boot-disk:local-lvm:vm-207-disk-0, local-lvm:vm-207-cloudinit, boot-disk:/opt/stacks/ai-consolidation, +1 more | pve-vzdump-primary | private-only | 2 probes |
| 211 | finance-stack | vm | auto | boot-only | boot-disk:local-lvm:vm-211-disk-0, local-lvm:vm-211-cloudinit, boot-disk:/opt/stacks/finance | pve-vzdump-primary, server-primary-finance-backups | docs.example-shop.com, docs.example.com, finances.example-shop.com, finances.example.com, firefly.example.com, investments.example-shop.com, investments.example.com | 4 probes |
| 212 | mint-data | vm | auto | data-vms | boot-disk:local-lvm:vm-212-disk-0, data-vms:pve:data/vms/vm-212-disk-0 (ZFS zvol, 320G) mounted at /mnt/data; DockerRootDir=/mnt/data/docker, data-vms:vm-212-disk-0, +3 more | pve-vzdump-primary, server-primary-mint-backups | private-only | 1 probes |
| 213 | mint-apps | vm | auto | boot-only | boot-disk:local-lvm:vm-213-disk-0, local-lvm:vm-213-cloudinit, boot-disk:/opt/stacks/mint-apps | pve-vzdump-primary | suppliers.example-shop.com, api.example-shop.com, customer.example-shop.com, customer.example-shop.com, estimator.example-shop.com, example-shop-app.example.com, example-shop.com, pricing.example-shop.com, pricing.example-shop.com, shipping.example-shop.com, shipping.example-shop.com, www.example-shop.com | 13 probes |
| 214 | communications-stack | vm | auto | data-vms | boot-disk:local-lvm:vm-214-disk-0, data-vms:pve:data/vms/vm-214-disk-0 (ZFS zvol, 1000G), data-vms:vm-214-disk-0, +4 more | pve-vzdump-primary, server-primary-communications-backups | mail-archive.example.com | 2 probes |
| 215 | surveillance-stack | vm | auto | nas-primary-vms | nas-primary:nas-primary-vms:vm-215-disk-0, boot-disk:pve:nas-primary-vms/vm-215-disk-{0,1} (boot 50G + data 100G), nas-primary:nas-primary-vms:vm-215-disk-1, +3 more | pve-vzdump-primary | private-only | 1 probes |
| 220 | archive-smb | lxc | auto | data-vms | boot-disk:data-vms:subvol-220-disk-0, data-vms:pve:data/vms/subvol-220-disk-0 (rootfs 8G); serves nas-primary datasets over Samba., tank:tank-docker:subvol-220-disk-0, +2 more | server-primary-archive-smb-snapshots | private-only | 0 probes |

## Tombstones

| VMID | Runtime | Hot Footprint | Cold Capsule | Review | Restore Rule |
| --- | --- | --- | --- | --- | --- |
| 200 | docker-host | none | /nas-primary/backups/vm-images/pve | 2026-09-06 | isolated sandbox only |

## Current Risks

- `infra-core`: 22% boot usage (11GB/48GB). Volumes only 250MB. Data on boot but lightweight (Infisical/Authentik/VW/PiHole). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `observability`: 20% boot usage (9.4GB/48GB). Volumes 1GB. Loki/Prometheus data small at current retention. Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `dev-tools`: 14% boot usage (6.3GB/48GB). Volumes 183MB. Gitea repos + PostgreSQL small at current scale. Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `ai-consolidation`: 5% boot usage (8.1GB/193GB). 200GB boot has massive headroom. Qdrant vectors + AnythingLLM small. Log rotation added. Re-evaluate if usage exceeds 40%. (ops/bindings/infra.storage.placement.policy.yaml)
- `finance-stack`: 12% boot usage (11GB/92GB) after truncating 59GB firefly-cron crash log. Actual data only 531MB. Fixed cron binary (crond→cron). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
