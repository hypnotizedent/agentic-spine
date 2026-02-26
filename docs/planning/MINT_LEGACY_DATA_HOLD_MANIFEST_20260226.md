---
status: authoritative
owner: "@ronny"
created: 2026-02-26
scope: mint-legacy-data-hold
authority: LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225
---

# Mint Legacy Data Hold Manifest (2026-02-26)

## Purpose

Establish a strict no-delete hold for legacy data-bearing paths during legacy
runtime detach work. This manifest is non-destructive and classification-only.

## Hold Policy (Fail Closed)

1. No `rm -rf` on hold paths.
2. No `docker compose down -v` touching hold paths.
3. No `docker volume rm` tied to hold paths.
4. No mutation under `/home/docker-host/backups` in this lane.
5. Any future destructive step requires explicit operator approval with a
   separate archive/migration receipt chain.

## Protected Paths (LEGACY_DATA_HOLD)

1. `/home/docker-host/backups`
2. `/mnt/data/mint-os/postgres`
3. `/mnt/docker/mint-os-data/minio`
4. `/home/docker-host/stacks/mail-archiver/postgres-data`
5. `/mnt/docker/hypno-ssot`

## Size + Timestamp Snapshot

Snapshot source:
- `receipts/audits/LEGACY_DATA_HOLD_RECEIPT_20260226T081048Z.txt`
- captured from `docker-host` at `2026-02-26T08:10:48Z` (UTC)

| Path | Exists | Observed Size | Directory Timestamp (UTC) | Latest File Marker (UTC) |
|---|---|---|---|---|
| `/home/docker-host/backups` | yes | `3.2G` | `2026-02-26 05:37:31` | `2026-02-26T05:37:31` |
| `/mnt/data/mint-os/postgres` | yes | `1.5G` | `2026-02-25 09:26:38` | `2026-02-26T05:46:33` |
| `/mnt/docker/mint-os-data/minio` | yes | `SIZE_TIMEOUT_OR_PERM` | `2026-01-28 04:36:36` | `2025-12-17T02:11:40` |
| `/home/docker-host/stacks/mail-archiver/postgres-data` | yes | `8.6G` | `2026-02-11 20:06:43` | `2026-02-11T20:06:43` |
| `/mnt/docker/hypno-ssot` | yes | `57G` | `2026-01-18 06:47:45` | `2026-01-18T07:20:56` |

Filesystem context:
- `/mnt/docker` is NFS (`192.168.1.184:/tank/docker`)
- root filesystem remains ext4 (`/dev/mapper/ubuntu--vg-ubuntu--lv`)

## Governed Receipts (This Session)

Run keys:
1. `CAP-20260226-030950__session.start__Reocl31228`
2. `CAP-20260226-031009__infra.docker_host.status__Ryof841008`
3. `CAP-20260226-031009__docker.compose.status__R9jjw41011`
4. `CAP-20260226-031009__services.health.status__Rvpbn41018`
5. `CAP-20260226-031009__cloudflare.tunnel.ingress.status__Rfap541023`

Receipts:
1. `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260226-030950__session.start__Reocl31228/receipt.md`
2. `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260226-031009__infra.docker_host.status__Ryof841008/receipt.md`
3. `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260226-031009__docker.compose.status__R9jjw41011/receipt.md`
4. `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260226-031009__services.health.status__Rvpbn41018/receipt.md`
5. `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260226-031009__cloudflare.tunnel.ingress.status__Rfap541023/receipt.md`

## Operator Note

This manifest freezes data-bearing legacy paths as hold-only. Legacy runtime
detach may continue in non-destructive mode (classification and stop-only) while
all protected paths remain untouched.
