# W62-B Gate Quality Scorecard

Generated: 2026-02-28T04:21:53Z
Source NDJSON: `/Users/ronnyworks/code/agentic-spine/ops/plugins/verify/state/verify-failure-class-history.ndjson`
Horizon: runs=11 start=2026-02-28T02:41:19Z end=2026-02-28T04:21:02Z

## Summary

- Active gates: **284** (registry total=285)
- Gates observed in horizon: **284**
- Blocking fail events: **1**
- Inferred blocking false-fail events (freshness + gate_bug): **0**
- Inferred false-fail ratio for blocking gates: **0.00%**
- Unknown failure events (non-gate ids): **0**

## Top Noisy Invariant Gates

| gate_id | gate_name | exposure_count | fail_count | fail_rate | deterministic | freshness | gate_bug |
|---|---|---:|---:|---:|---:|---:|---:|
| D67 | capability-map-lock | 11 | 1 | 9.09% | 1 | 0 | 0 |

## Highest Fail-Rate Gates (Observed)

| gate_id | gate_class | exposure_count | fail_count | fail_rate | pass_rate | inferred_false_fail_ratio |
|---|---|---:|---:|---:|---:|---:|
| D67 | invariant | 11 | 1 | 9.09% | 90.91% | 0.00% |
