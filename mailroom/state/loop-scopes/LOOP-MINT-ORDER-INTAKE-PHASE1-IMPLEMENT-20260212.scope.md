---
status: active
owner: "@ronny"
created: 2026-02-12
scope: loop-scope
loop_id: LOOP-MINT-ORDER-INTAKE-PHASE1-IMPLEMENT-20260212
severity: medium
---

# Loop Scope: LOOP-MINT-ORDER-INTAKE-PHASE1-IMPLEMENT-20260212

## Goal

Implement Option C from DECISION.md: extend artwork-module seeds with structured
metadata, add intake API endpoint, wire HAS_LINE_ITEM gate, update quote-page.
All product code in `mint-modules`.

## Boundary Rule

No spine edits except loop scope + receipts unless a change needs:
- New secret path (none expected)
- New service registration (none expected)
- New route (none expected)
- New VM dependency (none expected)

## Success Criteria

1. Seeds table has `metadata` JSONB column (migration).
2. `POST /api/v1/seeds/:id/metadata` endpoint sets/merges structured fields.
3. `HAS_LINE_ITEM` gate auto-satisfies when metadata has required keys.
4. quote-page sends structured metadata alongside request_text.
5. JSON schema for customer contract defined.
6. Tests pass and cover new endpoints + gate logic.
7. `typecheck`, `build`, `test` all pass for both artwork and quote-page.

## Phases

### P0: Schema + Migration (Worker D)
- [ ] Define JSON schema for customer contract metadata.
- [ ] Add migration: `ALTER TABLE seeds ADD COLUMN metadata JSONB DEFAULT NULL`.
- [ ] Add metadata to seed model/types.

### P1: API + Gate Logic (Worker E)
- [ ] Add `POST /api/v1/seeds/:id/metadata` endpoint.
- [ ] Wire HAS_LINE_ITEM gate: auto-satisfy when required metadata keys present.
- [ ] Add `GET /api/v1/seeds?needs_line_item=true` filter.
- [ ] Update quote-page to send structured metadata.

### P2: Tests (Worker F)
- [ ] Tests for metadata endpoint (set, merge, validation).
- [ ] Tests for gate auto-satisfy logic.
- [ ] Tests for quote-page structured metadata submission.
- [ ] Gate: typecheck, build, test pass for both modules.

### P3: Closeout
- [ ] All tests pass.
- [ ] Pushed to origin + github.
- [ ] Loop closed with evidence.

## Notes

Product-first loop. Worker terminals write to `mint-modules` only.
Terminal C (control-plane) applies spine scope + receipts only.
