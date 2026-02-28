# W61 Lane C Verify Shadow Receipt

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W61-AGENT-FRICTION-CONSOLIDATION-20260228-20260303`
Lane: C (`verify surface shadow unification`)

## Implemented

1. Added canonical wrapper runtime: `ops/plugins/verify/bin/verify-run`.
2. Registered wrapper capability: `verify.run`.
3. Scope profiles implemented:
   - `fast` = invariants (`core`)
   - `domain <domain>` = invariants + domain freshness (`core + domain`)
   - `release` = full release suite
4. Added shadow mode parity diffing against existing verify paths.
5. Added failure-class telemetry emission and persistence:
   - classes: `deterministic`, `freshness`, `gate_bug`
   - history artifact: `ops/plugins/verify/state/verify-failure-class-history.ndjson`

## Evidence

- `verify.run fast --shadow --json`
  - run key: `CAP-20260227-215731__verify.run__Rcax889244`
  - parity: PASS (delta=0)
- `verify.run domain communications --shadow --json`
  - run key: `CAP-20260227-215734__verify.run__Rok4g88361`
  - parity: PASS (delta=0)
- `verify.run release --json`
  - run key: `CAP-20260227-214554__verify.run__Rfp4f82295`
  - wrapper executes release path and records blocking failure class telemetry

## Output Artifacts

- `docs/planning/W61_VERIFY_WRAPPER_SHADOW_PARITY_REPORT.md`
- `docs/planning/W61_FAILURE_CLASS_BASELINE_REPORT.md`
- `ops/plugins/verify/state/verify-failure-class-history.ndjson`
