# LOOP-MINT-FRESH-SLATE-UPLOAD-LEGACY-REMOVE-20260212

- **Status:** closed
- **Created:** 2026-02-12
- **Closed:** 2026-02-12
- **Owner:** Terminal C (single-writer)
- **Parent:** LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-20260212
- **Blocker for:** P6 Cloudflare cutover

## Goal

Remove legacy `orders` table dependency from files-api `upload/prepare` endpoint
so fresh-slate (VM 212/213) is truly independent of mint-os-postgres on docker-host.

## Root Cause

`POST /api/v1/files/upload/prepare` queries the `orders` table to look up `visual_id`.
This table does not exist in the fresh-slate `mint_modules` database on VM 212.
Error: `relation "orders" does not exist`.

## Phases

- P0: Baseline recert ✅
- P1: Root-cause pinpoint (file:line) ✅
- P2a: Make db.ts additive (legacy + fresh-slate exports) ✅
- P2b: Migrate upload paths to fresh-slate DB functions ✅
- P2c: Contract stabilization + docs + commit ✅
- P3: Recert ✅

## Resolution

All active upload paths (`prepare`, `confirm`, `download`, `ingest/exists`) now use
fresh-slate DB functions (`resolveEntity`, `createAssetRecord`, `getAssetById`, `getAssetByObjectKey`)
backed by `artwork_seeds`, `artwork_jobs`, and `artwork_assets` tables.

Legacy `orders`/`pending_jobs`/`job_files` functions kept in db.ts as compat exports
but are no longer called from any active path.

### Commit Evidence

- `a2b0b2f` — 7 files, 405 insertions, 161 deletions
  - db.ts: additive (legacy compat preserved, fresh-slate added)
  - upload.ts: entityRef/assetId (was visualId/fileId)
  - routes/files.ts: fresh-slate lookups + compat aliases
  - presign.test.ts + confirm-upload.test.ts: updated for fresh-slate
  - API.md v2.0.0 + WORKFLOW.md: contract + deprecation schedule

### Recert Evidence

- Typecheck: PASS
- Tests: 95/95 PASS (6 test files)
- spine.verify: PASS (all drift gates)
- gaps.status: 0 open gaps
- services.health: files-api-v2 OK, mint-data OK, mint-apps OK
- docker.compose: mint-data 3/3, mint-apps 3/3

### Receipt IDs

- `CAP-20260212-095754__spine.verify__Rkrn899743`
- `CAP-20260212-095827__gaps.status__Rfbyy10041`
- `CAP-20260212-095829__services.health.status__Rcuak10101`
- `CAP-20260212-095844__docker.compose.status__R5bhh10603`

## Files Involved (P1 Root-Cause)

### Legacy dependency chain (3 functions, 2 tables):
- `db.ts:27-71` — `resolveVisualId()` queries `orders` (line 35-40) then `pending_jobs` (line 52-58)
- `db.ts:94-130` — `createJobFile()` inserts into `job_files` table
- `db.ts:132-170` — `getJobFileById()` reads from `job_files` table
- `db.ts:241-277` — `getJobFileBySourceRef()` reads from `job_files` table

### Call chain:
- `upload.ts:93` — `prepareUpload()` calls `db.resolveVisualId()`
- `upload.ts:195` — `confirmUpload()` calls `db.resolveVisualId()` again
- `upload.ts:244` — `confirmUpload()` calls `db.createJobFile()`

### Fresh-slate tables available (ticket.ts is already 100% fresh-slate):
- `artwork_seeds` (UUID id) — intake entities
- `artwork_jobs` (UUID id, job_number bigint) — operational entities
- `artwork_assets` + `artwork_asset_links` — file refs with entity binding

## Decision

NO-GO on Cloudflare cutover until this loop closes. **NOW CLOSED — cutover unblocked.**
