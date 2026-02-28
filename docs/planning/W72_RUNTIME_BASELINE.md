# W72 Runtime Baseline

Wave: `W72_RUNTIME_RECOVERY_HA_MEDIA_FRESHNESS_20260228`
Loop: `LOOP-SPINE-W72-RUNTIME-RECOVERY-HA-MEDIA-FRESHNESS-20260228-20260228`

## Preflight Run Keys
- `session.start`: `CAP-20260228-045959__session.start__R81ny22141`
- `loops.status`: `CAP-20260228-050021__loops.status__R3svq28259`
- `gaps.status`: `CAP-20260228-050021__gaps.status__Rmyow28289`
- `loops.create`: `CAP-20260228-050030__loops.create__Rew8o30481`
- `verify.freshness.reconcile` (baseline): `CAP-20260228-050045__verify.freshness.reconcile__Rjgvm31749`

## Baseline Counters
- open_loops: `23`
- open_gaps: `92`
- orphaned_open_gaps: `0`
- freshness_unresolved_count: `1`

## Baseline Target Gate State
Evidence log: `/tmp/w72_target_gate_baseline.log`

| gate_id | baseline_state | evidence |
|---|---|---|
| D113 | FAIL | `/tmp/w72_target_gate_baseline.log` |
| D118 | FAIL | `/tmp/w72_target_gate_baseline.log` |
| D188 | PASS | `/tmp/w72_target_gate_baseline.log` |
| D191 | PASS | `/tmp/w72_target_gate_baseline.log` |
| D192 | PASS | `/tmp/w72_target_gate_baseline.log` |
| D193 | PASS | `/tmp/w72_target_gate_baseline.log` |
| D194 | PASS | `/tmp/w72_target_gate_baseline.log` |
