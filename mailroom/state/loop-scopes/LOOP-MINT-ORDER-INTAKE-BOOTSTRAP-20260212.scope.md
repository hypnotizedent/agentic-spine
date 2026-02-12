---
status: open
owner: "@ronny"
created: 2026-02-12
scope: loop-scope
loop_id: LOOP-MINT-ORDER-INTAKE-BOOTSTRAP-20260212
severity: medium
---

# Loop Scope: LOOP-MINT-ORDER-INTAKE-BOOTSTRAP-20260212

## Goal

Bootstrap the order-intake module as a runnable TypeScript library. Exports
canonical types, validation functions, and constants for the customer contract
schema. No Express service — this is a shared contract definition module.

## Boundary Rule

No spine edits except loop scope + receipts unless a change needs:
- New secret path (none expected)
- New service registration (none expected)
- New route (none expected)
- New VM dependency (none expected)

## Success Criteria

1. `package.json` with typecheck, build, test scripts.
2. `tsconfig.json` matching workspace pattern (ES2022, NodeNext).
3. TypeScript types derived from `schema/customer-contract.schema.json`.
4. Validation functions: `validateContract()`, `isContractComplete()`.
5. Constants: `REQUIRED_METADATA_KEYS`, `DECORATION_TYPES`, `DELIVERY_METHODS`, `SUPPLIED_BY_OPTIONS`.
6. `src/index.ts` re-exports all public API.
7. Tests cover types, validation, and constants.
8. `npm run typecheck && npm run build && npm test` all pass.

## Phases

### P0: Scaffolding (Worker D)
- [ ] Create `package.json` (library, no Express).
- [ ] Create `tsconfig.json` (ES2022, NodeNext, declaration).
- [ ] Create `vitest.config.ts`.
- [ ] Create `src/index.ts` entry point.

### P1: Types + Validation + Constants (Worker E)
- [ ] `src/types.ts` — TypeScript interfaces for customer contract metadata.
- [ ] `src/constants.ts` — Required keys, decoration types, delivery methods, supplied-by options.
- [ ] `src/validate.ts` — `validateContract()`, `isContractComplete()`, schema-level checks.
- [ ] Wire exports through `src/index.ts`.

### P2: Tests (Worker F)
- [ ] Tests for validation functions (complete, incomplete, edge cases).
- [ ] Tests for constants (enum coverage, required keys match schema).
- [ ] Tests for type exports (compile-time checks).
- [ ] Gate: `typecheck`, `build`, `test` all pass.

### P3: Closeout
- [ ] All tests pass.
- [ ] Pushed to origin + github.
- [ ] Loop closed with evidence.

## Notes

Product-first loop. Workers write to `mint-modules` only.
Terminal C (control-plane) applies spine scope + receipts only.
