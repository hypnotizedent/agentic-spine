---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
scope: loop-scope
loop_id: LOOP-MINT-END2END-SMOKE-20260212
severity: medium
---

# Loop Scope: LOOP-MINT-END2END-SMOKE-20260212

## Goal

Build end-to-end smoke tests for the order-intake service: boot verification,
schema endpoint, contract validation + normalization, auth guard, and 404 handler.
Add in-memory files-api harness for cross-module test assertions.

## Boundary Rule

Workers only edit mint-modules. Spine edits = scope + receipts + closeout only.

## Phases

### P0: Worker D — Test Harness
- [x] mock-files-api.ts: in-memory artwork-module (GET /health, POST /api/v1/seeds, POST /api/v1/seeds/:id/metadata, GET /api/v1/seeds/:id) with getSeeds()/getSeed()/reset() assertion helpers
- [x] test-servers.ts: ephemeral HTTP server start/stop on OS-assigned ports

### P1: Worker E — E2E Smoke Tests + Wiring
- [x] e2e-smoke.test.ts: 8 tests (boot, schema, validate x3, auth x2, 404)
- [x] package.json: test:e2e script
- [x] README.md: e2e smoke section + updated public API exports
- [x] MINT_END2END_SMOKE.md: operator runbook with command sequence + failure triage

### P2: Terminal C — Recert + Closeout
- [x] typecheck + build + test pass (order-intake 99/99, quote-page 51/51)
- [x] Both remotes in sync (origin + github)
- [x] Loop closed with evidence

## Evidence

| Check | Result |
|-------|--------|
| `npm run typecheck` (order-intake) | PASS |
| `npm run build` (order-intake) | PASS |
| `npm test` (order-intake) | 99/99 PASS (54 validate + 37 intake + 8 e2e smoke) |
| `npm run typecheck` (quote-page) | PASS |
| `npm run build` (quote-page) | PASS |
| `npm test` (quote-page) | 51/51 PASS |
| mint-modules origin push | `a5616c3` |
| mint-modules github push | `a5616c3` |

### Commits (mint-modules)
- `26a2ee5` — in-memory files-api harness for e2e smoke
- `a5616c3` — e2e smoke test, script, runbook, README update
