---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
scope: loop-scope
loop_id: LOOP-MINT-ARTWORK-PHASE1-20260212
severity: medium
---

# Loop Scope: LOOP-MINT-ARTWORK-PHASE1-20260212

## Goal

Ship artwork module Phase 1: presigned upload/download, storage contract, tests.
All product code lives in `mint-modules`. Spine edits limited to this scope file
and receipts unless infra/secrets/routing must change.

## Boundary Rule

No spine edits except loop scope + receipts unless a change needs:
- New secret path (Infisical `/spine/services/artwork/`)
- New service registration (health probe, compose target)
- New route (tunnel ingress, DNS)
- New VM dependency

## Success Criteria

1. Presigned upload endpoint works end-to-end (client → presigned URL → storage).
2. Presigned download endpoint returns time-limited URLs for stored assets.
3. Storage contract documented (where files land, retention, access pattern).
4. Tests pass (vitest suite covers upload/download/error paths).
5. No secrets hardcoded — all via Infisical namespace.

## Phases

### P0: Contract
- [x] Define storage contract (S3-compatible vs local, path structure, retention).
- [x] Define API contract (endpoints, request/response shapes, auth).
- [x] Confirm Infisical namespace `/spine/services/artwork/` exists or create it.

### P1: Implementation
- [x] Presigned upload endpoint.
- [x] Presigned download endpoint.
- [x] Storage adapter (MinIO on docker-host or new target).

### P2: Tests
- [x] Unit tests for presign logic.
- [x] Integration tests for upload/download flow.
- [x] Error path coverage (expired URLs, missing files, auth failures).

### P3: Closeout
- [x] All tests pass.
- [x] API contract doc committed to `mint-modules`.
- [x] Loop closed with evidence.

## Evidence

| Check | Result |
|-------|--------|
| `npm run typecheck` | PASS |
| `npm run build` | PASS |
| `npm test` | 54/54 PASS (was 34, added 20) |
| `authority.project.status` | GOVERNED (8/8) |
| `spine.verify` | PASS D1-D71 |
| `gaps.status` | 0 open |
| mint-modules origin push | `eb7b7c3` |
| mint-modules github push | `eb7b7c3` |

### Commits (mint-modules)
- `8b52b2b` — D: contract docs (API.md, SPEC.md, STORAGE_CONTRACT.md)
- `8e15ff2` — E: implementation (presigned routes, storage adapter, config)
- `1a2203a` — F: tests (34 tests, vitest suite)
- `eb7b7c3` — C: presigned route contract alignment + 20 additional tests

## Notes

Product-first loop. Worker terminals write to `mint-modules` only.
Terminal C (control-plane) applies spine scope + receipts only.
