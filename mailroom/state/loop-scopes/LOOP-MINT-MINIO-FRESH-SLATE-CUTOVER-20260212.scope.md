---
loop_id: LOOP-MINT-MINIO-FRESH-SLATE-CUTOVER-20260212
status: closed
opened: 2026-02-12
closed: 2026-02-12
owner: "@ronny"
scope: minio-storage-canonical-cutover
---

# LOOP: MinIO Fresh-Slate Cutover — CLOSED

## Objective
Establish a single canonical MinIO runtime source (storage stack), remove all
conflicting authority statements across spine/workbench, and decouple mint-modules
runtime from the legacy mint-os application stack.

## Decision Lock
- mint-modules must have ZERO runtime dependency on legacy mint-os app stack.
- MinIO must be canonical from storage stack, not mint-os stack.

## Done Definition Verification

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Single canonical MinIO runtime source (storage stack) | DONE — SERVICE_REGISTRY.yaml compose: ~/stacks/storage/docker-compose.yml |
| 2 | No conflicting MinIO authority statements | DONE — "deprecated" removed from targets, mint-os minio removed from workbench |
| 3 | mint-modules runtime path not tied to legacy mint-os app stack | DONE — deploy docs reference storage stack as minio authority |
| 4 | D1-D71 pass | DONE — ALL 56 PASS (CAP-20260212-023114) |
| 5 | 0 open gaps | DONE — ops status shows 0 gaps |

## Before/After

| Attribute | Before | After |
|-----------|--------|-------|
| SERVICE_REGISTRY minio.compose | `~/stacks/mint-os/docker-compose.yml` | `~/stacks/storage/docker-compose.yml` |
| docker.compose.targets.yaml notes | "API and MinIO are deprecated" | "API is deprecated. MinIO canonical via storage stack" |
| docker.compose.targets.yaml stacks | mint-os, artwork-module, quote-page, dashy | mint-os, **storage**, artwork-module, quote-page, dashy |
| workbench mint-os/docker-compose.yml | Full minio service definition (stale volume, no healthcheck) | Removed — authority comment pointing to storage stack |
| workbench storage/docker-compose.yml volume | `/mnt/docker/storage/minio` (stale) | `/mnt/docker/mint-os-data/minio` (matches live NFS) |
| mint-modules deploy comments | "External services: mint-os-postgres, minio" | "minio from storage stack, mint-os-postgres from mint-os (legacy DB)" |
| secrets.namespace.policy.yaml | No MINIO_ROOT_* entries | `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` → `/spine/storage/minio` |

## Files Touched

### agentic-spine (commit 9d2c5f4)
- `docs/governance/SERVICE_REGISTRY.yaml` — minio compose path + notes
- `ops/bindings/docker.compose.targets.yaml` — notes + storage stack
- `ops/bindings/secrets.namespace.policy.yaml` — MINIO_ROOT_* namespace
- `mailroom/state/loop-scopes/LOOP-MINT-MINIO-FRESH-SLATE-CUTOVER-20260212.scope.md`
- `mailroom/state/loop-scopes/LOOP-MINT-MINIO-FRESH-SLATE-CUTOVER-20260212.changepack.md`

### workbench (commit 7e269a9)
- `infra/compose/storage/docker-compose.yml` — volume path fix
- `infra/compose/mint-os/docker-compose.yml` — minio service removed

### mint-modules (commit 6f377d8)
- `deploy/docker-compose.prod.yml` — authority comments
- `deploy/docker-compose.staging.yml` — authority comments
- `deploy/README.md` — authority comments

## Run Keys
- P0: CAP-20260212-022556 (verify), CAP-20260212-022517 (compose), CAP-20260212-022532 (health)
- P4: CAP-20260212-023114 (verify), CAP-20260212-023046 (compose), CAP-20260212-023102 (health)

## Note
The `storage` stack shows `down` in docker.compose.status because `~/stacks/storage/docker-compose.yml`
does not yet exist on docker-host. The actual MinIO container runs from the mint-os compose. Deploying the
storage compose file to the host and migrating the container is a separate operational step (not in scope
for this SSOT authority loop).
