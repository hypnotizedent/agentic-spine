# PLAN-AOF-GAP-SCHEMA-ENFORCEMENT-20260303

> Coordinator plan artifact for `LOOP-AOF-GAP-SCHEMA-CONFORMANCE-SELF-GROWTH-20260303`.
> Mode: current/up-next lane; execute immediately after current W2 lanes park.

## Problem Statement

Current AOF enforcement verifies naming/status/date conventions but does not
strictly validate gap entries against `ops/bindings/gap.schema.yaml`.

Result: new concepts can be expressed narratively (reports/loop tables) before
becoming authoritative structured fields.

## Target State

A gap field is valid only if it exists in the authority schema.
Unknown keys fail pre-commit and drift gate checks.

## Deliverables

1. `ops/bindings/gap.schema.yaml` updated to include current authoritative fields.
2. `ops/bindings/spine.schema.conventions.yaml` gains schema-bound strict mode for `operational.gaps.yaml`.
3. `ops/plugins/verify/bin/schema-conventions-audit` enforces schema-bound allowlist checks.
4. `surfaces/verify/d332-gap-schema-conformance-lock.sh` added.
5. D332 registered in:
   - `ops/bindings/gate.registry.yaml`
   - `ops/bindings/gate.execution.topology.yaml`
6. Fast verify includes and passes D332.

## Wave Plan

### W0 Baseline
- `session.start`, `verify.run -- fast`, `loops.status`, `gaps.status`.

### W1 Schema Reality Alignment
- Add optional fields to `gap.schema.yaml` that are already in active usage.
- Confirm `gaps.file` output parity.

### W2 Conventions Contract Hardening
- Add `schema_bound_files` section in `spine.schema.conventions.yaml`.
- Define strict mode for `ops/bindings/operational.gaps.yaml`.

### W3 Audit Enforcement
- Extend `schema-conventions-audit` to:
  - load schema-bound file config,
  - resolve allowed fields from schema,
  - fail on unknown keys.

### W4 Drift Gate Addition
- Add D332 script and register it.
- Place in fast ring only if runtime budget remains acceptable.

### W5 Validation + Closeout
- Run fast verify.
- Run adversarial check (temp unknown field) expecting hard fail.
- Revert adversarial edit.
- Close loop/gaps with receipts.

## Risks

- Over-strict enforcement may fail on legacy corpus fields not declared yet.
- Fast verify runtime may increase with D332 in core ring.

## Mitigations

- Keep explicit legacy exception list narrow and documented.
- If runtime budget tight, start D332 in non-core ring and promote after timing pass.

## Blockers (Current)

- Sequencing blocker only: Worker lanes W2 A/B/C are currently in flight.
- This loop is next in queue, not deferred.

## Linked Gaps

- GAP-OP-1411
- GAP-OP-1412
