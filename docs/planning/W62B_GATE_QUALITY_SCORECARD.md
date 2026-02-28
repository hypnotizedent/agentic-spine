# W62-B Gate Quality Scorecard

Generated: 2026-02-28T06:35:01Z
Source NDJSON: `/Users/ronnyworks/code/agentic-spine/ops/plugins/verify/state/verify-failure-class-history.ndjson`
Horizon: runs=21 start=2026-02-28T02:41:19Z end=2026-02-28T06:34:08Z

## Summary

- Active gates: **287** (registry total=288)
- Gates observed in horizon: **287**
- Blocking fail events: **1**
- Inferred blocking false-fail events (freshness + gate_bug): **0**
- Inferred false-fail ratio for blocking gates: **0.00%**
- Unknown failure events (non-gate ids): **0**

## Top Noisy Invariant Gates

| gate_id | gate_name | exposure_count | fail_count | fail_rate | deterministic | freshness | gate_bug |
|---|---|---:|---:|---:|---:|---:|---:|
| D67 | capability-map-lock | 21 | 1 | 4.76% | 1 | 0 | 0 |

## Highest Fail-Rate Gates (Observed)

| gate_id | gate_class | exposure_count | fail_count | fail_rate | pass_rate | inferred_false_fail_ratio |
|---|---|---:|---:|---:|---:|---:|
| D67 | invariant | 21 | 1 | 4.76% | 95.24% | 0.00% |
