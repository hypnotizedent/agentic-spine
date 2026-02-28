# W61 Failure Class Baseline Report

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W61-ENTRY-PROJECTION-VERIFY-UNIFICATION-20260228-20260303`
Telemetry source: `ops/plugins/verify/state/verify-failure-class-history.ndjson`

## Summary

- runs_scanned: **7**
- unique_failure_keys: **2**

## Gate Quality Baseline

| gate_id | fail_rate | classified_real_drift_count | candidate_action | notes |
|---|---:|---:|---|---|
| `D67` | 14.29% | 1 | promote | low fail rate in current baseline window |
| `RELEASE_SUITE` | 14.29% | 1 | retire-review | release suite failing without gate-level ids; needs suite decomposition evidence |

## Classification Contract

- Allowed classes: `deterministic`, `freshness`, `gate_bug`
- Contract: `ops/bindings/verify.failure.classification.contract.yaml`
