---
status: generated
owner: "@ronny"
last_verified: 2026-04-07
scope: shop-rack-scorecard
source_binding: ops/bindings/shop.storage.map.yaml
---

# Shop Rack Scorecard

- Generated: `2026-04-07T21:37:45Z`
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
| 202 | automation-stack | vm | auto | data-vms | data-vms:pve:data/vms/vm-202-disk-0 (ZFS zvol, 100G), /home/automation/backups/n8n-workflows, /home/automation/stacks | pve-vzdump-primary, r730xd-infra-core-backups | chat.ronny.works, n8n.ronny.works | 4 probes |
| 203 | immich | vm | auto | tank-docker | tank:tank/immich | pve-vzdump-primary | photos.ronny.works | 2 probes |
| 204 | infra-core | vm | auto | boot-only | boot-disk:infra-core boot disk (50G), boot-disk:/opt/stacks | pve-vzdump-primary, r730xd-infra-core-backups | auth.ronny.works, pihole.ronny.works, vault.ronny.works | 6 probes |
| 205 | observability | vm | auto | boot-only | boot-disk:observability boot disk (50G), boot-disk:/opt/stacks | pve-vzdump-primary | dash.ronny.works, grafana.ronny.works | 6 probes, node-exporter |
| 206 | dev-tools | vm | auto | boot-only | boot-disk:dev-tools boot disk (50G), boot-disk:/opt/stacks/gitea | pve-vzdump-primary, r730xd-dev-tools-backups | git.ronny.works | 1 probes |
| 207 | ai-consolidation | vm | auto | boot-only | boot-disk:ai-consolidation boot disk (200G), boot-disk:/opt/stacks/ai-consolidation, boot-disk:/opt/stacks/spine-workers | pve-vzdump-primary | private-only | 2 probes |
| 211 | finance-stack | vm | auto | boot-only | boot-disk:finance-stack boot disk (96G), boot-disk:/opt/stacks/finance | pve-vzdump-primary, r730xd-finance-backups | docs.mintprints.com, docs.ronny.works, finances.mintprints.com, finances.ronny.works, firefly.ronny.works, investments.mintprints.com, investments.ronny.works | 4 probes |
| 212 | mint-data | vm | auto | data-vms | data-vms:pve:data/vms/vm-212-disk-0 (ZFS zvol, 320G) mounted at /mnt/data; DockerRootDir=/mnt/data/docker, /opt/stacks/mint-data | pve-vzdump-primary, r730xd-mint-backups | private-only | 1 probes |
| 213 | mint-apps | vm | auto | boot-only | boot-disk:mint-apps boot disk (50G), boot-disk:/opt/stacks/mint-apps | pve-vzdump-primary | suppliers.mintprints.co, api.mintprints.com, customer.mintprints.co, customer.mintprints.com, estimator.mintprints.co, mintprints-app.ronny.works, mintprints.com, pricing.mintprints.co, pricing.mintprints.com, shipping.mintprints.co, shipping.mintprints.com, www.mintprints.com | 13 probes |
| 214 | communications-stack | vm | auto | data-vms | md1400:pve:data/vms/vm-214-disk-0 (ZFS zvol, 1000G), /opt/stacks/communications-stack, /srv/mail-archiver/backups | pve-vzdump-primary, r730xd-communications-backups | mail-archive.ronny.works | 2 probes |
| 215 | surveillance-stack | vm | auto | md1400-vms | boot-disk:pve:md1400-vms/vm-215-disk-{0,1} (boot 50G + data 100G) | pve-vzdump-primary | private-only | 1 probes |
| 220 | archive-smb | lxc | auto | data-vms | data-vms:pve:data/vms/subvol-220-disk-0 (rootfs 8G); serves md1400 datasets over Samba., md1400:/md1400/archive/live-share/mint-legacy, md1400:/md1400/archive/live-share/ronny-projects | r730xd-archive-smb-snapshots | private-only | 0 probes |

## Tombstones

| VMID | Runtime | Hot Footprint | Cold Capsule | Review | Restore Rule |
| --- | --- | --- | --- | --- | --- |
| 200 | docker-host | none | /md1400/backup-cold/vzdump/pve | 2026-09-06 | isolated sandbox only |

## Current Risks

- `infra-core`: 22% boot usage (11GB/48GB). Volumes only 250MB. Data on boot but lightweight (Infisical/Authentik/VW/PiHole). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `observability`: 20% boot usage (9.4GB/48GB). Volumes 1GB. Loki/Prometheus data small at current retention. Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `dev-tools`: 14% boot usage (6.3GB/48GB). Volumes 183MB. Gitea repos + PostgreSQL small at current scale. Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `ai-consolidation`: 5% boot usage (8.1GB/193GB). 200GB boot has massive headroom. Qdrant vectors + AnythingLLM small. Log rotation added. Re-evaluate if usage exceeds 40%. (ops/bindings/infra.storage.placement.policy.yaml)
- `finance-stack`: 12% boot usage (11GB/92GB) after truncating 59GB firefly-cron crash log. Actual data only 531MB. Fixed cron binary (crond→cron). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
