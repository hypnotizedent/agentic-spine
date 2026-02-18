---
loop_id: LOOP-AOF-DECOMPOSITION-VOCABULARY-NORMALIZE-20260218
created: 2026-02-18
status: active
owner: "@ronny"
scope: aof
priority: high
objective: Establish a canonical AOF-governed decomposition vocabulary for sub-loop work units, replacing ad-hoc WS/Move/Wave/Phase/Step/P-tier usage with a single enforceable contract.
---

# Loop Scope: LOOP-AOF-DECOMPOSITION-VOCABULARY-NORMALIZE-20260218

## Objective

Establish a canonical AOF-governed decomposition vocabulary for sub-loop work units, replacing ad-hoc WS/Move/Wave/Phase/Step/P-tier usage with a single enforceable contract.

## Parent Gap

- GAP-OP-666

## Scope

- Audit all active loop scopes and product docs for decomposition vocabulary usage (WS, Move, Wave, Phase, Step, P0/P1/P2).
- Select one canonical term (or a minimal governed set) for sub-loop decomposition.
- Add the canonical vocabulary to `ops/bindings/spine.schema.conventions.yaml`.
- Add a drift gate to enforce the canonical vocabulary in new loop scopes and product docs.
- Retrofit existing active loop scopes and product docs to use the canonical term(s).

## Out Of Scope

- Renaming closed/historical loop scopes (leave as-is for audit trail).
- Changes to the AOF policy runtime (presets, knobs, tenant profiles).

## Execution Pack

1. Baseline and route:
   - `./bin/ops status`
   - `./bin/ops cap run stability.control.snapshot`
   - `./bin/ops cap run verify.route.recommend`
2. Vocabulary audit:
   - Scan all `mailroom/state/loop-scopes/*.scope.md` and `docs/product/` for decomposition terms.
   - Produce a frequency table of WS/Move/Wave/Phase/Step/P-tier usage.
3. Canonical vocabulary contract:
   - Update `ops/bindings/spine.schema.conventions.yaml` with approved decomposition terms.
   - Document the decision in a brief conventions note.
4. Enforcement gate:
   - Add a drift gate to validate new loop scopes and product docs use only canonical terms.
   - Register gate in `ops/bindings/gate.registry.yaml`.
5. Retrofit active artifacts:
   - Update active loop scopes and product docs to use canonical vocabulary.
6. Verification:
   - `./bin/ops cap run verify.core.run`
   - `./bin/ops cap run verify.pack.run aof`
7. Lifecycle close:
   - `echo "yes" | ./bin/ops cap run gaps.close --id GAP-OP-666 --status fixed --fixed-in "<run-keys>"`
   - `./bin/ops loops close LOOP-AOF-DECOMPOSITION-VOCABULARY-NORMALIZE-20260218`

## Acceptance

- Canonical decomposition vocabulary is defined in `spine.schema.conventions.yaml`.
- Drift gate enforces vocabulary in new loop scopes and product docs.
- Active artifacts retrofitted to canonical terms.
- All verify packs pass.
- Gap and loop close with receipt-linked evidence.
