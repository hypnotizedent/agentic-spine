# W70 Acceptance Matrix

Wave: W70_WORKBENCH_VERIFY_BUDGET_CALIBRATION_20260228
Loop: LOOP-SPINE-W70-WORKBENCH-VERIFY-BUDGET-CALIBRATION-20260228-20260228-20260228

| id | criterion | result | evidence |
|---|---|---|---|
| A1 | 12-run baseline captured with timing stats | PASS | `docs/planning/W70_WORKBENCH_BUDGET_BASELINE_REPORT.md` + `.json` |
| A2 | 27/27 gates pass across baseline runs | PASS | baseline report: all_runs_27_pass_0_fail=true |
| A3 | calibrated budget justified by p95-based policy | PASS | `docs/planning/W70_BUDGET_CALIBRATION_DECISION.md` |
| A4 | regression lock for budget drift implemented | PASS | `ops/plugins/verify/bin/workbench-budget-regression-lock`, `docs/planning/W70_BUDGET_REGRESSION_LOCK_REPORT.md` |
| A5 | post-change workbench pack no longer budget-fails under normal run | PASS | `CAP-20260228-044153__verify.pack.run__R3i2011264` |
| A6 | no regression in core/secrets/comms/mint/fast/domain verify | PASS | phase3 run keys + mint rerun `CAP-20260228-044400__verify.pack.run__Rkibj49965` |
| A7 | orphaned_open_gaps remains 0 | PASS | `CAP-20260228-044349__gaps.status__Rwlax47378` |
| A8 | branch parity local=origin=github=share | PASS | `docs/planning/W70_PROMOTION_PARITY_RECEIPT.md` |
| A9 | clean branch status | PASS | `docs/planning/W70_BRANCH_ZERO_STATUS_REPORT.md` |
| A10 | attestations all true | PASS | `docs/planning/W70_SUPERVISOR_MASTER_RECEIPT.md` |

Acceptance summary: 10/10 PASS
