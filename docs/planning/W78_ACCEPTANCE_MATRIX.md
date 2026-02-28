# W78 Acceptance Matrix

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228

| id | criterion | result | evidence | blocker |
|---|---|---|---|---|
| A1 | Truth matrix complete with evidence per claim | PASS | `docs/planning/W78_TRUTH_MATRIX.md` |  |
| A2 | No unresolved invariant silent-pass pattern in targeted HA gates | PASS | `CAP-20260228-082937__verify.pack.run__R9t3o74492` (D293 PASS); script diffs in D113/D114/D118/D120 |  |
| A3 | Rogue VM gate exists and runs | PASS | `surfaces/verify/d294-proxmox-rogue-vm-detection-lock.sh`; included in hygiene-weekly run key above |  |
| A4 | Undeclared stack gate exists and runs | PASS | `surfaces/verify/d295-undeclared-docker-stack-detection-lock.sh`; included in hygiene-weekly run key above |  |
| A5 | Critical freshness gates fully mapped | PASS | `docs/planning/W78_FRESHNESS_COVERAGE_REPORT.md` |  |
| A6 | Launchd runtime contract includes 3 missing labels | PASS | `ops/bindings/launchd.runtime.contract.yaml` |  |
| A7 | Required verify block passes or blockers explicit | FAIL | `docs/planning/W78_RUN_KEY_LEDGER.md` | `W78-BLK-001` |
| A8 | orphaned_open_gaps remains 0 | PASS | `CAP-20260228-083126__gaps.status__Rrasq2305` |  |
| A9 | Telemetry exception preserved unstaged | PASS | `git status` shows only `ops/plugins/verify/state/verify-failure-class-history.ndjson` unstaged at closeout |  |
| A10 | Branch-zero classification has 0 ambiguous rows | PASS | `docs/planning/W78_BRANCH_ZERO_REPORT.md` |  |

## Blockers

| blocker_id | description | owner | next_action |
|---|---|---|---|
| W78-BLK-001 | D148 launchagent install/load parity fails without runtime enablement window (`com.ronny.ha-baseline-refresh`, `com.ronny.domain-inventory-refresh-daily`, `com.ronny.extension-index-refresh-daily`) | @ronny | Execute tokened runtime-enable path with `RELEASE_RUNTIME_CHANGE_WINDOW`, then rerun W78 verify block |
