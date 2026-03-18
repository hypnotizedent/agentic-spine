---
status: generated
owner: "@ronny"
last_verified: 2026-03-18
scope: estate-boringness-scorecard
source_binding: ops/bindings/estate.surface.register.yaml
---

# Estate Boringness Scorecard

- Generated: `2026-03-18T05:10:52Z`
- Rebuild: `./bin/ops cap run infra.estate.boringness.build`
- Repo surfaces tracked: `2`
- Ghosts: `10`
- Compatibility holds: `24`
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
| shop | no | hot=tank, warm=media, cold=md1400 | media is at 95% usage. The pool has about 1.37T free, but clients only see about 798G available over NFS.; Client-visible /media payload already accounts for about 15.9TiB of canonical movie/TV/music/archive content, so the remaining easy reclaim is mostly downloads.; Downloads still contribute about 2.25TiB of regenerable pressure even after the duplicate-drain and snapshot cleanup wave.; download-stack automation still logs FreeSpaceSpecification zero-free-space failures and SQLite lock churn, so import backlog behavior is not yet boring. |
| home | no | hot=proxmox-home local-lvm, warm_backup=synology /volume1/backups/proxmox_backups/dump, warm_data=synology /volume1, cold_offsite=none_declared | No declared second-environment cold/offsite restore plane exists for home personal data on Synology.; Home switch ports 3/4/6 still rely on inferred endpoint identity instead of traced physical truth.; Synology mint-os residue remains as non-canonical historical hold. |

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
| homarr.ronny.works | home | public_route | Compatibility hold only. Canonical media control-plane truth is media-home, but Homarr itself is intentionally parked during jellyfin-only recovery. |
| investments.ronny.works | shop | public_route | Legacy finance alias retained for compatibility. Canonical public investment URL is investments.mintprints.com. |
| jellyfin.ronny.works | home | public_route | Compatibility hold only. Canonical media runtime is media-home; do not treat the old shop stack as live truth. |
| mcp.mintprints.co | shop | public_route | Legacy or deprecated MCP surface retained on .co by design. Keep on .co to avoid implying a current canonical Mint runtime. |
| media-export-overlay-drift | shop | storage_mount_overlay | Client-visible /media payload truth comes from the NFS export, not the host-local child dataset mount view at /media/movies, /media/tv, and /media/music. The old /media/movies-archive cross-pool mask and the Proxmox media-storage compatibility backend were removed on 2026-03-17. |
| minio.mintprints.co | shop | public_route | Legacy MinIO console alias retained during mintprints.com cutover. Canonical public URL is minio.mintprints.com. |
| mint-modules-deploy-wrapper | code | repo_support_surface | mint-modules/deploy remains an operator wrapper and compatibility surface, not the canonical runtime definition lane. |
| mintprints-app.ronny.works | shop | public_route | Cutover 2026-02-21 (LOOP-MINT-NEW-VM-SERVICES-E2E-20260221). Was docker-host. Legacy work alias; customer.mintprints.com is the canonical public URL. |
| mintprints.co | shop | public_route | Legacy compatibility apex. Not canonical for work surfaces; mintprints.com is the primary public work root. |
| music.ronny.works | home | public_route | Compatibility hold only. Canonical music runtime is media-home, but Navidrome is intentionally parked during jellyfin-only recovery. |
| pricing.mintprints.co | shop | public_route | Legacy pricing alias retained during mintprints.com cutover. Canonical public URL is pricing.mintprints.com. |
| requests.ronny.works | home | public_route | Compatibility hold only. Canonical request manager is media-home, but Jellyseerr is intentionally parked during jellyfin-only recovery. |
| shipping.mintprints.co | shop | public_route | Legacy shipping alias retained during mintprints.com cutover. Canonical public URL is shipping.mintprints.com. |
| spotisub.ronny.works | home | public_route | Compatibility hold only. Canonical Spotify sync surface is media-home, but Spotisub is intentionally parked during jellyfin-only recovery. |
| suppliers.mintprints.co | shop | public_route | Purpose-bound legacy hold. Keep suppliers.mintprints.co only for public lookup/MCP compatibility until the Pages/custom-domain migration to mintprints.com is complete. |
| synology-mint-os-legacy-review | home | storage_residue | Legacy mint-os residue remains on Synology at /volume1/backups/proxmox_backups/mint-os. Reviewed and non-canonical. |
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
| safe_to_migrate | legacy media-stack tarballs from /media/backups to /md1400/archive/media-holds/legacy-media-stack-backups | done | Canonical media config backups already live under /md1400/backup-cold/apps/media-config. The historical warm-lane tarballs are now fully parked on md1400 and no longer live on media. |
| safe_to_delete | media@forensic-20260226-2325 | done | Snapshot was destroyed on 2026-03-17 after legacy media-stack backups and the duplicate-download review hold were captured on md1400. |
| safe_to_delete | Synology mint-os legacy residue | candidate | Residue is reviewed and non-canonical, but it still functions as a historical hold and should be deleted only in a deliberate cleanup wave. |
| safe_to_migrate | mint-modules future, blocked, and deferred roots | ready | Spine lifecycle authority already declares these roots non-runtime; moving them behind explicit lifecycle boundaries will not change live runtime behavior. |
| safe_to_migrate | ronny-products parked app contracts | done | app.contract runtime status now matches the execution board: parked products are no longer marked active. |
| safe_to_change_drives | shop rack hot/warm/cold storage | blocked | The namespace is cleaner, /md1400/stage is back to empty posture, the Proxmox media-storage compatibility backend is gone, and the forensic snapshot was destroyed. Hardware change is still blocked because media remains at 95% usage, downloads still contribute about 2.25TiB of regenerable pressure, GAP-OP-1526 is still active, and import automation is still pinned by app-level free-space checks. |
| safe_to_change_drives | proxmox-home and Synology drives | blocked | Runtime backups exist on Synology, but the same enclosure remains canonical for home personal data and there is no declared second cold plane. |
