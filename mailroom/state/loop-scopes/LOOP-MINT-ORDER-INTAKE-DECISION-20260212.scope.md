---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
scope: loop-scope
loop_id: LOOP-MINT-ORDER-INTAKE-DECISION-20260212
severity: medium
---

# Loop Scope: LOOP-MINT-ORDER-INTAKE-DECISION-20260212

## Goal

Make architecture decision for order-intake module. Decision-only — no runtime mutations,
no infra/secrets/compose/VM changes.

## Allowed Writes

- `mint-modules/order-intake/DECISION.md`
- `mint-modules/order-intake/SPEC.md` (decision reflected)
- This scope file only (in spine)

## Deliverables

1. DECISION.md with options, scoring, final choice, not-now list.
2. SPEC.md updated to reflect decision.
3. Loop closed with evidence.

## Phases

### P0: Research
- [x] Read existing SPEC.md and artwork-module ticket system.
- [x] Understand HAS_LINE_ITEM gate, seed model, quote-page flow.

### P1: Decision
- [x] Write DECISION.md with A/B/C options and scoring.
- [x] Update SPEC.md status to reflect decision.

### P2: Closeout
- [x] Pushed to origin + github.
- [x] Loop closed with evidence.

## Evidence

| Check | Result |
|-------|--------|
| `authority.project.status` | GOVERNED (8/8) |
| `spine.verify` | PASS D1-D71 |
| `gaps.status` | 0 open |
| mint-modules origin push | `1c34f54` |
| mint-modules github push | `1c34f54` |

### Decision Summary
- **Option C selected**: contract-first via seed metadata extension
- No new service, no new DB tables, no new infra
- Extend seeds with JSONB `metadata` column, wire HAS_LINE_ITEM gate auto-satisfy
- 8 items on explicit "not now" list
- Implementation deferred to future loop
