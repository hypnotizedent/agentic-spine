---
status: generated
owner: "@ronny"
last_verified: 2026-05-05
scope: shop-rack-scorecard
source_binding: ops/bindings/shop.storage.map.yaml
---

# Shop Rack Scorecard

- Generated: `2026-05-05T20:00:51Z`
- Rebuild: `./bin/ops cap run infra.shop.storage.authority.build`
- Active runtimes: `12`
- Tombstones: `3`
- Public runtimes: `8`

## Substrate

| Plane | Canonical surface | Current truth |
| --- | --- | --- |
| Hypervisor | `ops/bindings/hardware.inventory.yaml` | `pve` is the only shop hypervisor. |
| Folded storage map | `ops/bindings/shop.storage.map.yaml` | Folded input subordinate to `payload.custody.status`; not an operator-facing storage authority. |
| Ingress | `ops/bindings/shop.ingress.map.yaml` + `ops/bindings/services.health.yaml` | Public reachability is derived from the runtime ingress authority plus active health surfaces. |

## Storage Tiers

| Tier | Plane | Purpose | Layout | Backing |
| --- | --- | --- | --- | --- |
| tank | hot_runtime | Primary hot VM/app/runtime pool on pve. | RAIDZ2 | sda-sdh |
| media | warm_payload | Media payload only or phased-out pressure lane. | RAIDZ1 | sdi-sdl |
| md1400 | cold_backup_archive_stage | Cold backup/archive/staging shelf for the shop environment. | RAIDZ2 (12 drives) | 12 physical drives |

## Media Pressure

- Observed: `unknown`
- media: `unknown used`, `unknown free`, `unknown%`
- md1400: `unknown used`, `unknown free`, `unknown%`
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
| 202 | automation-stack | vm | auto | data-vms | boot-disk:data-vms:vm-202-disk-0, data-vms:pve:data/vms/vm-202-disk-0 (ZFS zvol, 100G), tank:tank-vms:vm-202-disk-0, +2 more | pve-vzdump-cold-canonical, r730xd-infra-core-backups | chat.ronny.works, n8n.ronny.works | 4 probes |
| 203 | immich | vm | auto | tank-docker | tank:tank/immich, tank:pve:tank/immich | pve-vzdump-cold-canonical | photos.ronny.works | 2 probes |
| 204 | infra-core | vm | auto | boot-only | boot-disk:local-lvm:vm-204-disk-0, local-lvm:vm-204-cloudinit, boot-disk:/opt/stacks | pve-vzdump-cold-canonical, r730xd-infra-core-backups | auth.ronny.works, pihole.ronny.works, vault.ronny.works | 6 probes |
| 206 | dev-tools | vm | auto | boot-only | boot-disk:local-lvm:vm-206-disk-0, local-lvm:vm-206-cloudinit, boot-disk:/opt/stacks/gitea | pve-vzdump-cold-canonical, r730xd-dev-tools-backups | git.ronny.works | 1 probes |
| 207 | ai-consolidation | vm | auto | boot-only | boot-disk:local-lvm:vm-207-disk-0, local-lvm:vm-207-cloudinit, boot-disk:/opt/stacks/ai-consolidation, +1 more | pve-vzdump-cold-canonical | private-only | 1 probes |
| 211 | finance-stack | vm | auto | boot-only | boot-disk:local-lvm:vm-211-disk-0, local-lvm:vm-211-cloudinit, boot-disk:/opt/stacks/finance | pve-vzdump-cold-canonical, r730xd-finance-backups | docs.mintprints.com, docs.ronny.works, finances.mintprints.com, finances.ronny.works, firefly.ronny.works, investments.mintprints.com, investments.ronny.works | 4 probes |
| 212 | mint-data | vm | auto | data-vms | boot-disk:local-lvm:vm-212-disk-0, data-vms:pve:data/vms/vm-212-disk-0 (ZFS zvol, 320G) mounted at /mnt/data; DockerRootDir=/mnt/data/docker, data-vms:vm-212-disk-0, +3 more | pve-vzdump-cold-canonical, r730xd-mint-backups | private-only | 1 probes |
| 213 | mint-apps | vm | auto | boot-only | boot-disk:local-lvm:vm-213-disk-0, local-lvm:vm-213-cloudinit, boot-disk:/opt/stacks/mint-apps | pve-vzdump-cold-canonical | suppliers.mintprints.co, api.mintprints.com, customer.mintprints.co, customer.mintprints.com, estimator.mintprints.co, mintprints-app.ronny.works, mintprints.com, pricing.mintprints.co, pricing.mintprints.com, shipping.mintprints.co, shipping.mintprints.com, www.mintprints.com | 12 probes |
| 214 | communications-stack | vm | auto | data-vms | boot-disk:local-lvm:vm-214-disk-0, data-vms:pve:data/vms/vm-214-disk-0 (ZFS zvol, 1000G), data-vms:vm-214-disk-0, +4 more | pve-vzdump-cold-canonical, r730xd-communications-backups | mail-archive.ronny.works | 2 probes |
| 215 | surveillance-stack | vm | auto | md1400-vms | md1400:md1400-vms:vm-215-disk-0, boot-disk:pve:md1400-vms/vm-215-disk-{0,1} (boot 50G + data 100G), md1400:md1400-vms:vm-215-disk-1, +3 more | pve-vzdump-cold-canonical | private-only | 1 probes |
| 216 | observability-r620 | vm | unknown | boot-only | boot-disk:local-lvm:vm-216-disk-0, local-lvm:vm-216-cloudinit | pve-vzdump-cold-canonical | grafana.ronny.works | 5 probes, node-exporter |
| 221 | shop-files | lxc | auto | tank | none | r730xd-shop-files-backups | private-only | 0 probes |

## Tombstones

| VMID | Runtime | Hot Footprint | Cold Capsule | Review | Restore Rule |
| --- | --- | --- | --- | --- | --- |
| 200 | docker-host | none | /md1400/mint-legacy/200-docker-host | 2026-06-12 | isolated sandbox only |
| 209 | download-stack | local-lvm:vm-209-disk-0 | /md1400/backup-cold/vzdump/pve | 2026-04-22 | unspecified |
| 210 | streaming-stack | local-lvm:vm-210-disk-0 | /md1400/backup-cold/vzdump/pve | 2026-04-22 | unspecified |

## Current Risks

- `infra-core`: 22% boot usage (11GB/48GB). Volumes only 250MB. Data on boot but lightweight (Infisical/Authentik/VW/PiHole). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `dev-tools`: 14% boot usage (6.3GB/48GB). Volumes 183MB. Gitea repos + PostgreSQL small at current scale. Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `ai-consolidation`: 5% boot usage (8.1GB/193GB). 200GB boot has massive headroom. Direct RAG Qdrant vectors are small. Log rotation added. Re-evaluate if usage exceeds 40%. (ops/bindings/infra.storage.placement.policy.yaml)
- `finance-stack`: 12% boot usage (11GB/92GB) after truncating 59GB firefly-cron crash log. Actual data only 531MB. Fixed cron binary (crond→cron). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `observability-r620`: Canonical observability witness VM 216 on pve-r620. Boot-only runtime accepted while stack remains rebuildable and bounded by observability.witness.contract. (ops/bindings/infra.storage.placement.policy.yaml)
- `shop-files`: No placement row exists for this active runtime. (ops/bindings/infra.storage.placement.policy.yaml)
- `shop-files`: shop-files: missing placement row in infra.storage.placement.policy.yaml (ops/bindings/infra.storage.placement.policy.yaml)
- `download-stack`: Delete vm-200-disk-0 only after proving the md1400 cold capsule, capturing qm config, and recording artifact size or checksum. (ops/bindings/vm.lifecycle.yaml)
