---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
scope: loop-scope
loop_id: LOOP-MINT-CONTRACT-HARDENING-20260212
severity: medium
---

# Loop Scope: LOOP-MINT-CONTRACT-HARDENING-20260212

## Goal

Harden order-intake contract validation: strict schema (additionalProperties: false),
normalizeContract() for canonical form, stricter quantity validation (integer > 0 or
range pattern), unknown field rejection, CONTRACT_VERSION + ALLOWED_CONTRACT_KEYS constants.

## Boundary Rule

Workers only edit mint-modules. Spine edits = scope + receipts + closeout only.

## Phases

### P0: Worker D — Constants + Schema strictness
- [x] Add CONTRACT_VERSION, ALLOWED_CONTRACT_KEYS to constants.ts
- [x] Update schema to additionalProperties: false

### P1: Worker E — normalizeContract + strict validate
- [x] Add normalizeContract() (strip unknown keys, trim, lowercase decoration_type)
- [x] Harden validateContract() (reject unknown fields, range validation, integer > 0)

### P2: Worker F — Tests
- [x] Tests for normalizeContract (12+ cases)
- [x] Tests for strict validation (unknown fields, quantity edge cases, range bounds)
- [x] Tests for new constants (CONTRACT_VERSION, ALLOWED_CONTRACT_KEYS)

### P3: Closeout
- [x] typecheck + build + test pass (order-intake + quote-page)
- [x] Pushed to origin + github
- [x] Loop closed with evidence

## Evidence

| Check | Result |
|-------|--------|
| `npm run typecheck` (order-intake) | PASS |
| `npm run build` (order-intake) | PASS |
| `npm test` (order-intake) | 91/91 PASS (was 31) |
| `npm run typecheck` (quote-page) | PASS |
| `npm run build` (quote-page) | PASS |
| `npm test` (quote-page) | 51/51 PASS (was 18) |
| `gaps.status` | 0 open |
| mint-modules origin push | `16957b4` |
| mint-modules github push | `16957b4` |

### Commits (mint-modules)
- `4a5edeb` — harden order-intake contract schema and docs
- `e9e4f5f` — harden quote-page metadata normalization and tests
- `16957b4` — enforce strict contract validation and normalization
