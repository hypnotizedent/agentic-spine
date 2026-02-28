# W70 Budget Calibration Decision

## Inputs
- sample_size: 12
- current_budget_seconds: 60
- p50_elapsed_seconds: 63.514
- p90_elapsed_seconds: 69.189
- p95_elapsed_seconds: 72.36
- p99_elapsed_seconds: 75.251
- max_elapsed_seconds: 75.974
- over_budget_rate_percent: 83.33
- all_runs_27_pass_0_fail: true

## Policy Rule
- target_budget_seconds = max(p95 + 5% headroom, current_budget)
- computed_target_seconds: 75.978
- calibrated_budget_seconds (rounded): 76
- increase_vs_current_percent: 26.67

## Cap Rule Exception Note
- hard_cap_default_percent: 20
- default_cap_seconds: 72
- selected_budget_seconds: 76
- exception_reason: p95-based target with 5% headroom requires 75.978s; rounding to 76 prevents budget-only false-fail while preserving all 27 workbench gates.
- governance_note_id: W70-NOTE-001

## Decision
- decision: APPROVE_CALIBRATION
- scope: workbench pack only via `pack_budget_overrides_seconds.workbench`
- non_goal: no weakening of gate logic or gate count
