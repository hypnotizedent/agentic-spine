---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-MINIO-VOLUME-PATH-DIVERGENCE-20260210
severity: high
---

# Loop Scope: LOOP-MINIO-VOLUME-PATH-DIVERGENCE-20260210

## Source
- Live incident: MinIO console (docker-host:9001) shows zero buckets
- Investigation session: 2026-02-10

## Problem Statement

The MinIO volume path on the live docker-host compose diverged from the workbench
compose during the Jan 23 extraction. The live system points to an empty local-disk
directory while 86k+ objects (8 buckets) sit untouched on the NFS share. No loop,
change pack, or mailroom receipt exists for the extraction's runtime side — only the
workbench and SSOT docs were updated, never the live compose.

## Impact

- **Data availability**: All MinIO buckets invisible to the running container
- **Buckets affected**: artwork-intake, client-assets, customer-artwork, imprint-mockups (8,485), invoice-pdfs (12,865), line-item-mockups (43,351), production-files (21,340), suppliers
- **Data loss**: None — objects intact on NFS at `/mnt/docker/mint-os-data/minio/`
- **Other services**: Postgres (1.5GB), redis, production data — all intact on local disk

## Canonical Timeline

| Date | Event | Actor | Receipt |
|------|-------|-------|---------|
| 2025-12-17 | MinIO data directory created on local disk at `/mnt/data/mint-os/minio` | unknown | Birth timestamp on `/mnt/data/mint-os/` |
| 2025-12-17 | MinIO data seeded on NFS at `/mnt/docker/mint-os-data/minio/` | unknown | `format.json` ID `7a874f3f` (NFS) |
| 2026-01-09 | Compose backup taken (`docker-compose.yml.bak`) — already uses local-disk path `/mnt/data/mint-os/minio` | unknown | File timestamp on docker-host |
| 2026-01-22 | NFS directory `/mnt/docker/mint-os-data/` created on pve ZFS | unknown | Birth timestamp |
| 2026-01-23 | MinIO "extracted" to standalone infrastructure — container renamed `mint-os-minio` → `minio` | agent (Opus 4.5) | INFRASTRUCTURE_MAP.md lines 411, 769, 1360 |
| 2026-01-23 | Symlink created: `/mnt/docker/storage/minio` → `/mnt/docker/mint-os-data/minio` | unknown | Symlink timestamp 20:43 |
| 2026-01-30 | Live compose on docker-host rewritten (password hardening, container rename, files-api integration) — volume path unchanged | agent (Opus 4.5) | File timestamp; `.bak` diff |
| 2026-02-04 | Workbench compose committed at `infra/compose/storage/docker-compose.yml` with NFS path `/mnt/docker/storage/minio:/data` | hypnotizedent + Opus 4.5 | Workbench commit `2a0d37c` |
| 2026-02-05 | MINIO_STANDALONE_SSOT.md listed as "authoritative" in canonicalization | hypnotizedent + Opus 4.5 | Spine commit `6e0fbf3` |
| 2026-02-08 | GAP-OP-032 filed: "docker-host storage stack path does not exist" — closed by removing the invalid target, NOT fixing the volume path | CODE_AUDIT_20260208 | operational.gaps.yaml |
| 2026-02-10 | LOOP-MINTOS-REGISTRY-VS-HEALTH-PARITY closed — minio marked deprecated, health probes disabled | Opus 4.6 | Spine commit `9302edb` |
| 2026-02-10 17:08 | Full docker-host 502 outage begins (watchdog log shows `docker-compose.frontends.yml: no such file or directory`) | watchdog cron | `/var/log/mint-os-watchdog.log` |
| 2026-02-10 17:23 | All docker-host containers recreated — MinIO gets fresh empty dir, formats new pool (ID `2cb6d91b`), zero buckets | unknown trigger | Container creation timestamp; MinIO log "Formatting 1st pool" |

## SSOT Conflicts (5 layers)

### Conflict 1: Live compose vs workbench compose (VOLUME PATH)
- **Live** (`docker-host:~/stacks/mint-os/docker-compose.yml`): `/mnt/data/mint-os/minio:/data` → local disk (empty)
- **Workbench** (`infra/compose/storage/docker-compose.yml`): `/mnt/docker/storage/minio:/data` → NFS via symlink (has data)
- **Root cause**: Jan 23 extraction updated workbench but never deployed to docker-host

### Conflict 2: STACK_REGISTRY.yaml references phantom paths
- Claims `infrastructure/docker-host/mint-os/docker-compose.minio.yml` — **does not exist** in workbench
- Claims `infrastructure/storage/docker-compose.yml` — **does not exist** (actual: `infra/compose/storage/docker-compose.yml`)
- Root cause: STACK_REGISTRY authored against planned paths, not actual workbench layout

### Conflict 3: SERVICE_REGISTRY.yaml compose pointer
- Claims `compose: ~/stacks/mint-os/docker-compose.yml` — points to the live compose with the wrong volume path
- Extraction note says MinIO "now lives in `infrastructure/storage/docker-compose.yml`, not mint-os stack"
- But in reality MinIO is STILL defined inline in the mint-os compose on docker-host

### Conflict 4: INFRASTRUCTURE_MAP.md data path
- Line 769: "Now lives in `infrastructure/storage/docker-compose.yml`" — that file uses NFS path
- Actual live runtime: still in mint-os compose, still on local disk path
- Historical reference at `/mnt/docker/mint-os/vault/` (159GB) is a different directory entirely

### Conflict 5: MINIO_STANDALONE_SSOT.md
- Listed as "authoritative" in the Feb 5 canonicalization commit (`6e0fbf3`)
- **File does not exist** at `docs/infrastructure/storage/MINIO_STANDALONE_SSOT.md`

## Governance Failures

1. **No git on docker-host** — `~/stacks/mint-os/` has no `.git`. Compose mutations are unversioned and untraceable.
2. **No mailroom receipt** for the Jan 23 extraction runtime changes. Only SSOT docs were updated.
3. **No change pack** for the Jan 30 compose rewrite. Agent rewrote the file but left the wrong volume path.
4. **GAP-OP-032 was closed prematurely** — it identified the path mismatch but "fixed" it by removing the reference, not fixing the actual divergence.
5. **Deprecation masked the problem** — marking MinIO deprecated + disabling health probes meant nobody checked whether it actually worked.
6. **MinIO backup disabled** — `backup.inventory.yaml` has `enabled: false` for `app-minio`.
7. **Watchdog references nonexistent file** — `docker-compose.frontends.yml` does not exist, causing 15+ minutes of failed recovery loops.
8. **Two broken cron jobs** — `health-check.sh` (not found), `simplefin-sync` (wrong file owner) — noise in journal.

## Data State (as of 2026-02-10 17:53 UTC)

| Location | Path | Size | Format ID | Status |
|----------|------|------|-----------|--------|
| NFS (pve ZFS) | `/mnt/docker/mint-os-data/minio/` | 86k+ objects, 8 buckets | `7a874f3f` (Dec 17) | Intact, not mounted |
| NFS symlink | `/mnt/docker/storage/minio` → above | — | — | Valid |
| Local disk | `/mnt/data/mint-os/minio/` | 136KB (empty) | `2cb6d91b` (today) | Fresh format, zero buckets |

## Triage: mint-modules Audit (2026-02-10)

mint-modules (`~/code/mint-modules`) is the **canonical architecture source** for the
modular extraction. It correctly defines the target state:

- `files-api` joins `storage-network` (minio) + `mint-os-network` (postgres)
- MinIO reached via container DNS: `http://minio:9000`
- 7 buckets documented in CONNECTIONS.md (artwork-intake is write authority)

### Live docker-host vs mint-modules architecture

| What | mint-modules says | Live docker-host state |
|------|-------------------|----------------------|
| minio networks | `storage-network` + `mint-os-network` | `mint-os-network` only |
| storage-network | external, files-api + minio both join | Exists but **zero containers** attached |
| files-api | container `files-api` on port 3500 | **Never deployed** (not in `docker ps -a`) |
| minio volume | N/A (mint-modules doesn't define minio volumes) | `/mnt/data/mint-os/minio` (wrong, local disk) |
| minio compose | Workbench `infra/compose/storage/docker-compose.yml` | Still inline in `~/stacks/mint-os/docker-compose.yml` |

### Conflict 6: storage-network architecture never implemented
- `storage-network` Docker network was created on docker-host
- But minio was never added to it (live compose doesn't reference it)
- files-api was never deployed
- The entire extraction was docs + workbench compose only; zero runtime changes landed

### Updated P0 fix scope
The P0 fix must also add `storage-network` to the minio service definition in the live
compose, so that when files-api is eventually deployed, it can reach minio via container
DNS as mint-modules CONNECTIONS.md specifies.

## Required Actions

### P0 — Restore (immediate) — DONE
- [x] Update live compose volume: `/mnt/docker/mint-os-data/minio:/data`
- [x] Add `storage-network` to minio service in live compose
- [x] Restart minio — all 8 buckets visible, health endpoint PASS
- [x] Backup: `docker-compose.yml.bak.20260210-pre-p0`

### P1 — SSOT Reconciliation — DONE
- [x] STACK_REGISTRY.yaml: fixed phantom paths → `docker-host:~/stacks/mint-os/docker-compose.yml`
- [x] STACK_REGISTRY.yaml: storage stack path → `infra/compose/storage/` (marked reference-only)
- [x] SERVICE_REGISTRY.yaml: minio status `deprecated` → `active`, volume + networks documented
- [x] services.health.yaml: minio probe re-enabled
- [x] authority.json: MINIO_STANDALONE_SSOT.md → SERVICE_REGISTRY.yaml (minio entry)
- [x] GAP-OP-073 through GAP-OP-077 filed

### P2 — Governance Hardening — DONE (partial)
- [x] Fix watchdog: `docker-compose.frontends.yml` → `docker-compose.yml` (backup at .bak.20260210)
- [x] Disable broken health-check.sh cron (script does not exist in ronny-ops/scripts/)
- [x] Fix simplefin-sync cron.d ownership: docker-host → root:root
- [x] MinIO deprecation reversed: SERVICE_REGISTRY status=active, health probe re-enabled
- [ ] Git-init `~/stacks/mint-os/` on docker-host (deferred — separate scope)
- [ ] Enable MinIO backup in `backup.inventory.yaml` (deferred — separate scope)

### P3 — Drift Gate (deferred)
- [ ] Propose new drift gate: compose volume paths must match between workbench and live host
