---
status: generated
owner: "@ronny"
last_verified: 2026-03-19
scope: shop-rack-scorecard
source_binding: ops/bindings/shop.storage.map.yaml
---

# Shop Rack Scorecard

- Generated: `2026-03-19T15:52:55Z`
- Rebuild: `./bin/ops cap run infra.shop.storage.authority.build`
- Active runtimes: `14`
- Tombstones: `1`
- Public runtimes: `8`

## Substrate

| Plane | Canonical surface | Current truth |
| --- | --- | --- |
| Hypervisor | `ops/bindings/hardware.inventory.yaml` | `pve` is the only shop hypervisor. |
| Storage map | `ops/bindings/shop.storage.map.yaml` | Runtime, backup, and tombstone storage truth are projected from authoritative bindings. |
| Ingress | `docs/governance/SERVICE_REGISTRY.yaml` + `ops/bindings/domain.routing.registry.yaml` | Public reachability is derived from live service and route registry surfaces. |

## Storage Tiers

| Tier | Plane | Purpose | Layout | Backing |
| --- | --- | --- | --- | --- |
| tank | hot_runtime | Primary hot VM/app/runtime pool on pve. | RAIDZ2 | sda-sdh |
| media | warm_payload | Media payload only or phased-out pressure lane. | RAIDZ1 | sdi-sdl |
| md1400 | cold_backup_archive_stage | Cold backup/archive/staging shelf for the shop environment. | RAIDZ2 (12 drives) | 12 physical drives |

## Media Pressure

- Observed: `2026-03-12T05:08:17Z`
- media: `28.9T used`, `176G free`, `99%`
- md1400: `7.30T used`, `36.3T free`, `16%`
- Canonical payload: `15.9TiB`
- Regenerable runtime pressure: `2.61TiB`
- View truth: The client-visible /media export is authoritative for payload accounting. The host-local paths /media/movies, /media/tv, and /media/music are empty child datasets, and /media/movies-archive is currently masked by md1400/media-cold/movies-archive. NFS consumers still observe live parent payload at those paths, so host-local du/zfs output alone is not storage truth.


| Path | Surface Class | Reclaim Class | Usage | Purpose |
| --- | --- | --- | --- | --- |
| /mnt/media/movies | runtime | payload | 9.6T | Canonical movie library served to streaming-stack and maintained from download-stack. |
| /mnt/media/tv | runtime | payload | 5.5T | Canonical TV library served to streaming-stack and maintained from download-stack. |
| /mnt/media/downloads | runtime | regenerable | 2.7T | Active import/download lane for SABnzbd, qBittorrent, and related media tooling. |
| /mnt/media/music | runtime | payload | 666G | Canonical music library served to streaming-stack and maintained from download-stack. |
| /mnt/media/movies-archive | archive | archive | 205G | Radarr archive root reachable over the canonical /media export. |
| /mnt/media/backups | compatibility-hold | archive | 6.7M | Legacy warm-lane media-stack tarballs being drained to md1400; not canonical backup truth. |

| Lane | Status | Target | Current Size | Rationale |
| --- | --- | --- | --- | --- |
| media-stack-legacy-backups-drain | done | /media/backups | 0 | Canonical media config backups already live under /md1400/backup-cold/apps/media-config. These warm-lane tarballs are legacy archive residue and now live on md1400, not on media.
 |
| media-forensic-snapshot-hold | blocked | media@forensic-20260226-2325 | 278G | Retained forensic snapshot from the copy-first utilization upgrade. Deleting it in this wave would discard restore evidence; keeping it means deleted media blocks are not reclaimed immediately.
 |
| media-downloads-reclaim | candidate | /mnt/media/downloads | 2.7T | Downloads are the largest regenerable consumer on the warm lane. Reclaim should be selective and tool-aware, not a blind delete, but this is the highest-value live cleanup path once active imports are reviewed.
 |

## Active Runtime Units

| VMID | Runtime | Kind | Startup | Tier | Durable State | Backup Lane | Ingress | Monitoring |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 202 | automation-stack | vm | auto | tank-vms | tank:tank/vms/vm-202-disk-0, /home/automation/backups/n8n-workflows, /home/automation/stacks | pve-vzdump-primary, r730xd-infra-core-backups | chat.ronny.works, n8n.ronny.works | 4 probes |
| 203 | immich | vm | auto | tank-docker | tank:tank/immich | pve-vzdump-primary | private-only | 2 probes |
| 204 | infra-core | vm | auto | boot-only | boot-disk:infra-core boot disk (50G), boot-disk:/opt/stacks | pve-vzdump-primary, r730xd-infra-core-backups | auth.ronny.works, pihole.ronny.works, vault.ronny.works | 6 probes |
| 205 | observability | vm | auto | boot-only | boot-disk:observability boot disk (50G), boot-disk:/opt/stacks | pve-vzdump-primary | dash.ronny.works, grafana.ronny.works | 6 probes, node-exporter |
| 206 | dev-tools | vm | auto | boot-only | boot-disk:dev-tools boot disk (50G), boot-disk:/opt/stacks/gitea | pve-vzdump-primary, r730xd-dev-tools-backups | git.ronny.works | 1 probes |
| 207 | ai-consolidation | vm | auto | boot-only | boot-disk:ai-consolidation boot disk (200G), boot-disk:/opt/stacks/ai-consolidation | pve-vzdump-primary | private-only | 2 probes |
| 209 | download-stack | vm | auto | tank-docker | tank:tank/docker/download-stack, media:media, +2 more | r730xd-media-config-backups | private-only | 7 probes, node-exporter |
| 210 | streaming-stack | vm | auto | tank-docker | tank:tank/docker/streaming-stack, media:media, +2 more | r730xd-media-config-backups | homarr.ronny.works, jellyfin.ronny.works, music.ronny.works, requests.ronny.works, spotisub.ronny.works | 8 probes, node-exporter |
| 211 | finance-stack | vm | auto | boot-only | boot-disk:finance-stack boot disk (96G), boot-disk:/opt/stacks/finance | pve-vzdump-primary, r730xd-finance-backups | docs.mintprints.com, docs.ronny.works, finances.mintprints.com, finances.ronny.works, firefly.ronny.works, investments.mintprints.com, investments.ronny.works | 4 probes |
| 212 | mint-data | vm | auto | boot-only | tank-vms:/dev/vda ext4 secondary disk mounted at /mnt/data; DockerRootDir=/mnt/data/docker, boot-disk:/opt/stacks/mint-data | pve-vzdump-primary, r730xd-mint-backups | private-only | 1 probes |
| 213 | mint-apps | vm | auto | boot-only | boot-disk:mint-apps boot disk (50G), boot-disk:/opt/stacks/mint-apps | pve-vzdump-primary | suppliers.mintprints.co, customer.mintprints.co, customer.mintprints.com, estimator.mintprints.co, mintprints-app.ronny.works, mintprints.com, pricing.mintprints.co, pricing.mintprints.com, shipping.mintprints.co, shipping.mintprints.com, www.mintprints.com | 9 probes |
| 214 | communications-stack | vm | auto | tank-vms | tank:tank/vms/vm-214-disk-0, /opt/stacks/communications-stack, /srv/mail-archiver/backups | pve-vzdump-primary, r730xd-communications-backups | mail-archive.ronny.works | 2 probes |
| 215 | surveillance-stack | vm | auto | tank-vms | tank:/dev/vda ext4 secondary disk mounted at /mnt/data and surfaced via /srv/data/surveillance/{appstate,recordings,clips,snapshots} bind mounts. | pve-vzdump-primary | private-only | 1 probes |
| 220 | archive-smb | lxc | auto | md1400 | md1400:md1400 live-share datasets, md1400:/md1400/archive/live-share/mint-legacy, md1400:/md1400/archive/live-share/ronny-projects | r730xd-archive-smb-snapshots | private-only | 0 probes |

## Tombstones

| VMID | Runtime | Hot Footprint | Cold Capsule | Review | Restore Rule |
| --- | --- | --- | --- | --- | --- |
| 200 | docker-host | none | /md1400/backup-cold/vzdump/pve | 2026-09-06 | isolated sandbox only |

## Current Risks

- `automation-stack`: Boot disk is ZFS-backed zvol (not local-lvm). Docker volumes still on boot filesystem. Consider data disk for n8n/postgres. (ops/bindings/infra.storage.placement.policy.yaml)
- `infra-core`: 22% boot usage (11GB/48GB). Volumes only 250MB. Data on boot but lightweight (Infisical/Authentik/VW/PiHole). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `observability`: 20% boot usage (9.4GB/48GB). Volumes 1GB. Loki/Prometheus data small at current retention. Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `dev-tools`: 14% boot usage (6.3GB/48GB). Volumes 183MB. Gitea repos + PostgreSQL small at current scale. Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `ai-consolidation`: 5% boot usage (8.1GB/193GB). 200GB boot has massive headroom. Qdrant vectors + AnythingLLM small. Log rotation added. Re-evaluate if usage exceeds 40%. (ops/bindings/infra.storage.placement.policy.yaml)
- `finance-stack`: 12% boot usage (11GB/92GB) after truncating 59GB firefly-cron crash log. Actual data only 531MB. Fixed cron binary (crond→cron). Log rotation added. Re-evaluate if usage exceeds 60%. (ops/bindings/infra.storage.placement.policy.yaml)
- `communications-stack`: Boot is ZFS zvol (not local-lvm). Stalwart on named volume. Mail-archiver needs /srv/mail-archiver non-boot path. (ops/bindings/infra.storage.placement.policy.yaml)
- `media`: media is at 99% usage. NFS-visible canonical payload already accounts for about 15.9TiB (movies/tv/music plus movies-archive), downloads adds about 2.61TiB of regenerable pressure, the legacy warm-lane media-stack tarballs are now offloaded to md1400, and the retained forensic snapshot has grown to 278G, so the migration does not reclaim space immediately. (ops/bindings/shop.media.pressure.authority.yaml)
