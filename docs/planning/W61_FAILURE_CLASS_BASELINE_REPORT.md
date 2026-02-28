# W61 Failure Class Baseline Report

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W61-ENTRY-PROJECTION-VERIFY-UNIFICATION-20260228-20260303`
Telemetry source: `ops/plugins/verify/state/verify-failure-class-history.ndjson`

## Summary

- runs_scanned: **9**
- unique_failure_keys: **2**

## Gate Quality Baseline

| gate_id | fail_rate | classified_real_drift_count | candidate_action | notes |
|---|---:|---:|---|---|
| `D67` | 11.11% | 1 | promote | one deterministic failure during initial wrapper registration; no subsequent recurrences in current window |
| `RELEASE_SUITE` | 11.11% | 1 | retire-review | release suite failing without gate-level ids; needs suite decomposition evidence |

## Classification Contract

- Allowed classes: `deterministic`, `freshness`, `gate_bug`
- Contract: `ops/bindings/verify.failure.classification.contract.yaml`
