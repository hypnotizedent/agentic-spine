# W70 Budget Regression Lock Report

## Lock
- lock_script: `ops/plugins/verify/bin/workbench-budget-regression-lock`
- enforcement_path: `ops/plugins/verify/bin/verify-pack` (workbench pack preflight)

## Enforced Rules
1. `pack_budget_overrides_seconds.workbench` must be numeric.
2. Override must equal `calibrations.workbench_pack_standard.calibrated_budget_seconds`.
3. Override must be `>= budgets_seconds.standard`.
4. If override exceeds `approved_max_seconds_without_override`, a receipt-linked override reference must exist.
5. On violation, lock fails with explicit recalibration fix hint.

## Evidence
- direct_lock_execution: PASS
- workbench_pack_execution_with_lock: run_key `CAP-20260228-044153__verify.pack.run__R3i2011264`
- observed_budget_line: `budget: ring=standard elapsed=56.177s budget=76s delta=-19.823s`
