---
status: working
owner: "@ronny"
last_verified: 2026-02-26
scope: mint-storage-governance-contract
---

# Mint Storage Governance Contract (Wave 8)

## Objective

Define governance-only storage controls for Mint runtime surfaces (VM 212 `mint-data`, VM 213 `mint-apps`) so drift is measurable, linked, and promotion-ready without runtime mutations.

## Hard Boundary

- This wave is contracts + guards + linkage only.
- Runtime mutation is forbidden in this wave:
  - no VM mount edits
  - no `/etc/fstab` edits
  - no docker daemon/data-root edits
  - no container restart/redeploy/prune/delete actions

## Canonical Data Shape (Expected vs Actual)

All storage evidence and guards must align to these fields:

- `vm_id`
- `vm_role`
- `mount_inventory`: device, fs, size, used, avail, mountpoint, in_fstab, boot_or_data
- `docker_storage`: docker_root_dir, storage_driver, images_size, build_cache_size, local_volume_size
- `container_mounts`: container, mount_type, host_path, container_path, on_boot_drive
- `data_plane_validation`: postgres/minio/redis paths and persistence settings
- `app_plane_write_surface`: tmp/upload indicators + container rootfs writable size
- `drift_summary`: finding_id, severity, governance linkage

## STOR Linkage Authority

Authoritative mapping:

- `ops/bindings/mint.storage.findings.map.yaml`

Required governance invariant:

- Every `STOR-001..STOR-008` entry must map to at least one gap and one loop.
- `STOR-002` and `STOR-004` remain a single root-cause cluster: `docker-root-on-boot`.

## Wave Assignment

- `W8A`: contract/SSOT normalization
- `W8B`: boot-drive placement drift controls
- `W8C`: mint-data persistence/durability controls
- `W8D`: mint-apps write-surface + docker budget controls
- `W8E`: recurring storage-audit snapshot + regression-proof linkage
