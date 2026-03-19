---
status: generated
owner: "@ronny"
last_verified: 2026-03-19
scope: estate-boringness-scorecard
source_binding: ops/bindings/estate.surface.register.yaml
---

# Estate Boringness Scorecard

- Generated: `2026-03-19T15:11:44Z`
- Rebuild: `./bin/ops cap run infra.estate.boringness.build`
- Repo surfaces tracked: `2`
- Ghosts: `10`
- Compatibility holds: `20`
- Tombstones: `4`
- Unknowns: `1`

## Repo Closure

| Repo | Boring Enough | Purpose | Exact Blocker |
| --- | --- | --- | --- |
| mint-modules | yes | Mint Prints implementation repo for active modules plus future, blocked, deferred, and contract-only module roots. | none |
| ronny-products | yes | Parked product-orchestration repo with one live integration surface and two intentionally non-deployed product lanes. | none |

## Environment Closure

| Environment | Boring Enough | Storage Story | Exact Blocker |
| --- | --- | --- | --- |
| shop | no | hot=tank, warm=media, cold=md1400 | media is at 99% usage and only has about 189G free.; Client-visible /media payload already accounts for about 15.9TiB of canonical movie/TV/music/archive content, so the remaining easy reclaim is mostly downloads.; media@forensic-20260226-2325 is still retained as a forensic hold and has grown to 278G, so the completed backup drain still does not immediately reclaim matching space. |
| home | no | hot=proxmox-home local-lvm, warm_backup=synology /volume1/backups/proxmox_backups/dump, warm_data=synology /volume1, cold_offsite=none_declared | No declared second-environment cold/offsite restore plane exists for home personal data on Synology.; Home switch ports 3/4/6 still rely on inferred endpoint identity instead of traced physical truth.; Legacy Synology backup lanes are now tombstoned, but infrastructure/devices plus ghost backup roots still need later-wave cleanup. |

## Ghosts

| Surface | Environment | Kind | Note |
| --- | --- | --- | --- |
| admin.mintprints.co | shop | public_route | Legacy docker-host admin surface remains inventoried on .co, but no live Cloudflare tunnel route is published. Re-publish intentionally if the admin surface returns. |
| api.mintprints.co | shop | public_route | Legacy docker-host API surface remains inventoried on .co, but no live Cloudflare tunnel route is published. Current canonical API surface is api.mintprints.com. |
| kanban.mintprints.co | shop | public_route | Legacy docker-host kanban surface remains inventoried on .co, but no live Cloudflare tunnel route is published. Re-publish intentionally if the surface returns. |
| kanban.ronny.works | shop | public_route | Legacy docker-host workflow alias remains inventoried for compatibility, but no live Cloudflare tunnel route is published. Re-publish intentionally before treating this as active again. |
| mintprints-api.ronny.works | shop | public_route | Legacy docker-host API alias remains inventoried for compatibility, but no live Cloudflare tunnel route is published. Re-publish intentionally before treating this as active again. |
| mintprints-v3.ronny.works | shop | public_route | Legacy experimental work alias. Do not treat as a canonical public Mint surface. |
| production.mintprints.co | shop | public_route | Legacy docker-host production surface remains inventoried on .co, but no live Cloudflare tunnel route is published. Re-publish intentionally if the surface returns. |
| production.ronny.works | shop | public_route | Legacy docker-host production alias remains inventoried for compatibility, but no live Cloudflare tunnel route is published. Re-publish intentionally before treating this as active again. |
| send.mintprints.co | shop | public_route | Domain registered but service not deployed. Routing classified as direct. GAP-OP-1291c. |
| stock-dst.mintprints.co | shop | public_route | Legacy stock destination alias remains inventoried, but no live Cloudflare tunnel route is published. Rehome or retire intentionally before reactivation. |

## Compatibility Holds

| Surface | Environment | Kind | Note |
| --- | --- | --- | --- |
| artwork.mintprints.co | shop | public_route | Legacy Pages hold. Keep until artwork custom domain is moved to mintprints.com without breaking read-only browser access. |
| customer.mintprints.co | shop | public_route | Legacy customer alias retained during mintprints.com cutover. Canonical public URL is customer.mintprints.com. |
| docs.ronny.works | shop | public_route | Legacy finance alias retained for compatibility. Canonical public document URL is docs.mintprints.com. |
| estimator.mintprints.co | shop | public_route | Legacy pricing alias retained during mintprints.com cutover. Canonical public URL is pricing.mintprints.com. |
| files.mintprints.co | shop | public_route | Legacy file endpoint alias retained during mintprints.com cutover. Canonical public URL is files.mintprints.com. |
| finances.ronny.works | shop | public_route | Legacy finance alias retained for compatibility. Canonical public dashboard URL is finances.mintprints.com. |
| firefly.ronny.works | shop | public_route | Legacy finance alias retained for compatibility. Canonical public dashboard URL is finances.mintprints.com. |
| investments.ronny.works | shop | public_route | Legacy finance alias retained for compatibility. Canonical public investment URL is investments.mintprints.com. |
| mcp.mintprints.co | shop | public_route | Legacy or deprecated MCP surface retained on .co by design. Keep on .co to avoid implying a current canonical Mint runtime. |
| media-export-overlay-drift | shop | storage_mount_overlay | Client-visible /media payload truth comes from the NFS export, not the host-local child dataset mount view at /media/movies, /media/tv, /media/music, and /media/movies-archive. |
| media-forensic-20260226-2325 | shop | storage_snapshot_hold | Retained forensic snapshot on media preserves deleted blocks and blocks immediate reclaim during the copy-first normalization wave. |
| minio.mintprints.co | shop | public_route | Legacy MinIO console alias retained during mintprints.com cutover. Canonical public URL is minio.mintprints.com. |
| mint-modules-deploy-wrapper | code | repo_support_surface | mint-modules/deploy remains an operator wrapper and compatibility surface, not the canonical runtime definition lane. |
| mintprints-app.ronny.works | shop | public_route | Cutover 2026-02-21 (LOOP-MINT-NEW-VM-SERVICES-E2E-20260221). Was docker-host. Legacy work alias; customer.mintprints.com is the canonical public URL. |
| mintprints.co | shop | public_route | Legacy compatibility apex. Not canonical for work surfaces; mintprints.com is the primary public work root. |
| pricing.mintprints.co | shop | public_route | Legacy pricing alias retained during mintprints.com cutover. Canonical public URL is pricing.mintprints.com. |
| shipping.mintprints.co | shop | public_route | Legacy shipping alias retained during mintprints.com cutover. Canonical public URL is shipping.mintprints.com. |
| suppliers.mintprints.co | shop | public_route | Purpose-bound legacy hold. Keep suppliers.mintprints.co only for public lookup/MCP compatibility until the Pages/custom-domain migration to mintprints.com is complete. |
| synology-mint-os-legacy-review | home | storage_residue | Legacy mint-os residue is tombstoned under /volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue. Reviewed and non-canonical. |
| www.mintprints.co | shop | public_route | Legacy compatibility www. Not canonical for work surfaces; www.mintprints.com is the primary public host. |

## Tombstones

| Surface | Environment | Kind | Note |
| --- | --- | --- | --- |
| lxc-103-download-home | home | guest | Historical stopped guest recorded in home.proxmox.inventory.yaml. |
| vm-101-immich-home | home | guest | Historical stopped guest recorded in home.proxmox.inventory.yaml. |
| vm-102-vaultwarden | home | vm | Legacy Vaultwarden (superseded by infra-core) |
| vm-200-docker-host | shop | vm | TOMBSTONED 2026-03-06 after Mint data/control-plane retirement. Live 300G VM disk removed from hot storage on 2026-03-12; keep exactly one cold restore capsule on md1400 and do not return this guest to the runtime plane. Historically hosted mint-os, artwork-module, quote-page, minio, files-api, mint-os-postgres, and mint-os-redis on pre-spine Linux Mint. If recovery is needed, restore only into an isolated temporary sandbox identity with no legacy DNS/routes.
 |

## Unknowns

| Surface | Environment | Kind | Note |
| --- | --- | --- | --- |
| home-switch-port-identity | home | physical_network_gap | Home switch ports 3, 4, and 6 still have inferred endpoint identity only. |

## Final Decision Table

| Decision | Subject | Status | Rationale |
| --- | --- | --- | --- |
| safe_to_delete | vm-200-disk-0 on pve local-lvm | done | Cold capsule path/size/SHA-256 and qemu config were captured before delete, then qm disk unlink removed scsi0 and the backing LV on 2026-03-12T04:30:02Z. |
| safe_to_migrate | legacy media-stack tarballs from /media/backups to /md1400/media-cold/legacy-media-stack-backups | done | Canonical media config backups already live under /md1400/backup-cold/apps/media-config. The historical warm-lane tarballs are now fully parked on md1400 and no longer live on media. |
| safe_to_delete | media@forensic-20260226-2325 | blocked | Snapshot still acts as a forensic restore hold for the copy-first utilization wave. Deleting it would change the restore story, not just free space. |
| safe_to_delete | Synology mint-os legacy residue | candidate | Residue is reviewed, non-canonical, and now tombstoned under /volume1/backups/_legacy_tombstones/retired-20260319-mint-os-home-residue. Delete only in a deliberate cleanup wave. |
| safe_to_migrate | Synology stale backup lanes into /volume1/backups/_legacy_tombstones | done | Historical shop exact-offsite residue plus stale mint-os, home-assistant, finance, and media backup lanes were renamed into one explicit tombstone subtree on 2026-03-19 so they no longer look canonical. |
| safe_to_migrate | mint-modules future, blocked, and deferred roots | ready | Spine lifecycle authority already declares these roots non-runtime; moving them behind explicit lifecycle boundaries will not change live runtime behavior. |
| safe_to_migrate | ronny-products parked app contracts | done | app.contract runtime status now matches the execution board: parked products are no longer marked active. |
| safe_to_change_drives | shop rack hot/warm/cold storage | blocked | VM200 hot LV is gone, but media remains at 99% usage, downloads still contribute about 2.61TiB of regenerable pressure, and the retained forensic snapshot prevents warm-lane deletions from reclaiming space immediately. |
| safe_to_change_drives | proxmox-home and Synology drives | blocked | Runtime backups exist on Synology, but the same enclosure remains canonical for home personal data and there is no declared second cold plane. |
