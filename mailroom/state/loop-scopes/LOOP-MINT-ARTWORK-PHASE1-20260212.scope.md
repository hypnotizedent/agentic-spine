---
status: active
owner: "@ronny"
created: 2026-02-12
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
- [ ] Define storage contract (S3-compatible vs local, path structure, retention).
- [ ] Define API contract (endpoints, request/response shapes, auth).
- [ ] Confirm Infisical namespace `/spine/services/artwork/` exists or create it.

### P1: Implementation
- [ ] Presigned upload endpoint.
- [ ] Presigned download endpoint.
- [ ] Storage adapter (MinIO on docker-host or new target).

### P2: Tests
- [ ] Unit tests for presign logic.
- [ ] Integration tests for upload/download flow.
- [ ] Error path coverage (expired URLs, missing files, auth failures).

### P3: Closeout
- [ ] All tests pass.
- [ ] API contract doc committed to `mint-modules`.
- [ ] Loop closed with evidence.

## Notes

Product-first loop. Worker terminals write to `mint-modules` only.
Terminal C (control-plane) applies spine scope + receipts only.
