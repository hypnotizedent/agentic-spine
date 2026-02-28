# W62-B Gate Quality Scorecard

Generated: 2026-02-28T07:05:21Z
Source NDJSON: `/Users/ronnyworks/code/agentic-spine/ops/plugins/verify/state/verify-failure-class-history.ndjson`
Horizon: runs=27 start=2026-02-28T02:41:19Z end=2026-02-28T07:05:20Z

## Summary

- Active gates: **287** (registry total=288)
- Gates observed in horizon: **287**
- Blocking fail events: **9**
- Inferred blocking false-fail events (freshness + gate_bug): **2**
- Inferred false-fail ratio for blocking gates: **22.22%**
- Unknown failure events (non-gate ids): **0**

## Top Noisy Invariant Gates

| gate_id | gate_name | exposure_count | fail_count | fail_rate | deterministic | freshness | gate_bug |
|---|---|---:|---:|---:|---:|---:|---:|
| D31 | home-output-sink-lock | 2 | 2 | 100.00% | 2 | 0 | 0 |
| D84 | docs-index-registration-lock | 2 | 2 | 100.00% | 0 | 2 | 0 |
| D85 | gate-registry-parity-lock | 2 | 2 | 100.00% | 2 | 0 | 0 |
| D285 | entry-surface-gate-metadata-no-manual-drift-lock | 2 | 2 | 100.00% | 2 | 0 | 0 |
| D67 | capability-map-lock | 27 | 1 | 3.70% | 1 | 0 | 0 |

## Highest Fail-Rate Gates (Observed)

| gate_id | gate_class | exposure_count | fail_count | fail_rate | pass_rate | inferred_false_fail_ratio |
|---|---|---:|---:|---:|---:|---:|
| D31 | invariant | 2 | 2 | 100.00% | 0.00% | 0.00% |
| D84 | invariant | 2 | 2 | 100.00% | 0.00% | 100.00% |
| D85 | invariant | 2 | 2 | 100.00% | 0.00% | 0.00% |
| D285 | invariant | 2 | 2 | 100.00% | 0.00% | 0.00% |
| D67 | invariant | 27 | 1 | 3.70% | 96.30% | 0.00% |
