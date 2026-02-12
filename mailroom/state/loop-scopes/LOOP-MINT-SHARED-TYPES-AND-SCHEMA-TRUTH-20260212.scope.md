---
loop_id: LOOP-MINT-SHARED-TYPES-AND-SCHEMA-TRUTH-20260212
status: closed
closed: 2026-02-12
owner: "@ronny"
apply_owner: claude
opened: 2026-02-12
scope: Shared types package + SCHEMA_TRUTH doc for mint-modules
---

# LOOP-MINT-SHARED-TYPES-AND-SCHEMA-TRUTH-20260212

## Goal

Implement a canonical shared-types/schema-truth layer so modules can integrate without cross-module type drift or DB chaos.

## Deliverables

1. `packages/shared-types/` — canonical types, enums, constants
2. `docs/ARCHITECTURE/SCHEMA_TRUTH.md` — field naming, alias maps, normalization rules
3. All 3 modules import shared-types (no duplicate enum/type definitions)
4. Parity tests ensuring all modules use same canonical values

## Boundaries

- Product edits: mint-modules only
- Spine edits: scope + receipts + closeout only
- No runtime deploy/cutover

## Evidence

### Baseline
- spine.verify: PASS (CAP-20260212-020751)
- ops status: 0 loops, 0 gaps
- authority.project.status: GOVERNED

### Deliverables
- `packages/shared-types/` — @mint-modules/shared-types v0.1.0, canonical types/enums/constants
- `docs/ARCHITECTURE/SCHEMA_TRUTH.md` — column naming lock, decoration canon, normalization rules
- artwork: imports SeedMetadata + REQUIRED_METADATA_KEYS from shared-types
- quote-page: imports DECORATION_ALIASES + DECORATION_TYPES + QuoteMetadata from shared-types
- order-intake: re-exports all types/constants from shared-types (zero local definitions)

### Recert
- shared-types: typecheck PASS, build PASS
- artwork: typecheck PASS, build PASS, 95 tests PASS
- quote-page: typecheck PASS, build PASS, 51 tests PASS
- order-intake: typecheck PASS, build PASS, 113 tests PASS
- Architecture guard: 28/28 PASS
- spine.verify: PASS (CAP-20260212-021411)

### Commits
- mint-modules: `70053ca` — shared types + schema truth (16 files, 396 insertions, 139 deletions)
- spine: (this commit) — loop scope
