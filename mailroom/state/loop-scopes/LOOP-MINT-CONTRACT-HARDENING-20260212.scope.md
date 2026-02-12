---
status: open
owner: "@ronny"
created: 2026-02-12
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
- [ ] Add CONTRACT_VERSION, ALLOWED_CONTRACT_KEYS to constants.ts
- [ ] Update schema to additionalProperties: false

### P1: Worker E — normalizeContract + strict validate
- [ ] Add normalizeContract() (strip unknown keys, trim, lowercase decoration_type)
- [ ] Harden validateContract() (reject unknown fields, range validation, integer > 0)

### P2: Worker F — Tests
- [ ] Tests for normalizeContract (12+ cases)
- [ ] Tests for strict validation (unknown fields, quantity edge cases, range bounds)
- [ ] Tests for new constants (CONTRACT_VERSION, ALLOWED_CONTRACT_KEYS)

### P3: Closeout
- [ ] typecheck + build + test pass (order-intake + quote-page)
- [ ] Pushed to origin + github
- [ ] Loop closed with evidence
