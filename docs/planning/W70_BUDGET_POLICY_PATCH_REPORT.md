# W70 Budget Policy Patch Report

## Changed Files
- `ops/bindings/verify.ring.policy.yaml`
- `ops/plugins/verify/bin/verify-pack`
- `ops/plugins/verify/bin/verify-topology`
- `ops/plugins/verify/bin/workbench-budget-regression-lock` (new)

## Patch Summary
1. Added `pack_budget_overrides_seconds.workbench: 76` while preserving global `budgets_seconds.standard: 60`.
2. Added calibration metadata under `calibrations.workbench_pack_standard`.
3. Added `VERIFY_RING_BUDGET_OVERRIDE_SECONDS` handling in `verify-topology` for standard ring runs.
4. Updated `verify-pack run workbench` to:
   - enforce `workbench-budget-regression-lock`
   - inject calibrated budget override deterministically.

## Non-Regression Intent
- Workbench still runs same 27 gates.
- No gate scripts removed, skipped, or reclassified.
- Core/secrets/communications/mint + verify.run wrapper surfaces unchanged except normal verification execution.
