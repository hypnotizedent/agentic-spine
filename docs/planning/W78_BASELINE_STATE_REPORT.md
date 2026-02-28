# W78 Baseline State Report

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228
branch: codex/w78-truth-first-reliability-hardening-20260228
loop_id: LOOP-W78-TRUTH-FIRST-RELIABILITY-HARDENING-20260228

## Baseline Counters

- open_loops: 21
- open_gaps: 95
- orphaned_open_gaps: 0
- freshness_unresolved: 1

## Baseline Run Keys

| command | run_key | result |
|---|---|---|
| `./bin/ops cap run session.start` | `CAP-20260228-081005__session.start__Rfilm4028` | PASS |
| `./bin/ops cap run loops.status` | `CAP-20260228-081028__loops.status__Rvggz11305` | PASS |
| `./bin/ops cap run gaps.status` | `CAP-20260228-081028__gaps.status__R6y7911307` | PASS |
| `./bin/ops cap run gate.topology.validate` | `CAP-20260228-081028__gate.topology.validate__Rcw7e11313` | PASS |
| `./bin/ops cap run verify.route.recommend` | `CAP-20260228-081028__verify.route.recommend__Rwb1711315` | PASS |
| `./bin/ops cap run loops.create --name "W78 Truth First Reliability Hardening" --objective "Truth-first reconciliation and reliability hardening with token-gated runtime/cleanup paths"` | `CAP-20260228-081032__loops.create__Rhwrp14029` | PASS |
| `./bin/ops cap run verify.freshness.reconcile` | `CAP-20260228-081243__verify.freshness.reconcile__Rqggx21308` | PASS (`unresolved_count=1`) |

## Notes

- Preserved telemetry exception (unstaged):
  - `/Users/ronnyworks/code/agentic-spine/ops/plugins/verify/state/verify-failure-class-history.ndjson`
