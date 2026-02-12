---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
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
- [x] Define JSON schema for customer contract metadata.
- [x] Add migration: `ALTER TABLE seeds ADD COLUMN metadata JSONB DEFAULT NULL`.
- [x] Add metadata to seed model/types.

### P1: API + Gate Logic (Worker E)
- [x] Add `POST /api/v1/seeds/:id/metadata` endpoint.
- [x] Wire HAS_LINE_ITEM gate: auto-satisfy when required metadata keys present.
- [x] Add `GET /api/v1/seeds?needs_line_item=true` filter.
- [x] Update quote-page to send structured metadata.

### P2: Tests (Worker F)
- [x] Tests for metadata endpoint (set, merge, validation).
- [x] Tests for gate auto-satisfy logic.
- [x] Tests for quote-page structured metadata submission.
- [x] Gate: typecheck, build, test pass for both modules.

### P3: Closeout
- [x] All tests pass.
- [x] Pushed to origin + github.
- [x] Loop closed with evidence.

## Evidence

| Check | Result |
|-------|--------|
| `npm run typecheck` (artwork) | PASS |
| `npm run build` (artwork) | PASS |
| `npm test` (artwork) | 81/81 PASS (from 54) |
| `npm run typecheck` (quote-page) | PASS |
| `npm run build` (quote-page) | PASS |
| `npm test` (quote-page) | 18/18 PASS |
| `authority.project.status` | GOVERNED (7/7) |
| `spine.verify` | D1-D65,D67-D71 PASS; D66 WARN (pre-existing media parity) |
| `gaps.status` | 0 open |
| mint-modules origin push | `f1a1b50` |
| mint-modules github push | `f1a1b50` |

### Changes (mint-modules `f1a1b50`)
- **artwork/migrations/20260212_seed_metadata.sql**: `ALTER TABLE artwork_seeds ADD COLUMN metadata JSONB`
- **order-intake/schema/customer-contract.schema.json**: JSON schema (product, quantity, decoration_type required)
- **artwork/src/services/ticket.ts**: `SeedMetadata` type, `REQUIRED_METADATA_KEYS`, `setSeedMetadata()`, `isMetadataComplete()`, `autoSatisfyLineItemGate()`, `listSeeds()`, metadata in all seed queries
- **artwork/src/routes/seeds.ts**: `POST /:id/metadata`, `GET /` (list with filters), metadata+has_line_item in all responses
- **artwork/API.md**: Order Intake section + updated endpoint index
- **artwork/src/__tests__/seed-metadata.test.ts**: 18 tests (metadata CRUD, validation, gate auto-satisfy)
- **artwork/src/__tests__/metadata-logic.test.ts**: 9 tests (isMetadataComplete unit tests)
- **quote-page/src/routes/quote.ts**: sends structured metadata alongside request_text
- **quote-page/src/services/seeds.ts**: metadata field in CreateSeedPayload

### Implementation Summary
- **Option C executed**: no new service, no new DB tables, no new infra
- **Backward compatible**: existing seeds without metadata continue working (column is nullable)
- **Gate auto-satisfy**: `HAS_LINE_ITEM` gate auto-satisfies when seed metadata has `product`, `quantity`, `decoration_type`
- **Escape hatch preserved**: schema can be promoted to dedicated tables (Option A) later if needed

## Notes

Product-first loop. Worker terminals write to `mint-modules` only.
Terminal C (control-plane) applies spine scope + receipts only.
D66 failure is pre-existing media agent MCP parity issue — not related to this loop.
