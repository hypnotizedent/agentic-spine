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
| A7 | Required verify block passes or blockers explicit | PASS | `docs/planning/W78_RUN_KEY_LEDGER.md`; W78B verify keys `CAP-20260228-090506__verify.pack.run__Rpcdv68723`, `CAP-20260228-090507__verify.pack.run__Rs05h69505`, `CAP-20260228-090620__verify.pack.run__Ru1kk89380`, `CAP-20260228-090633__verify.run__Rz2f491470` |  |
| A8 | orphaned_open_gaps remains 0 | PASS | `CAP-20260228-090752__gaps.status__Rkr6d3030` |  |
| A9 | Telemetry exception preserved unstaged | PASS | `git status` shows only `ops/plugins/verify/state/verify-failure-class-history.ndjson` unstaged at closeout |  |
| A10 | Branch-zero classification has 0 ambiguous rows | PASS | `docs/planning/W78_BRANCH_ZERO_REPORT.md` |  |

## Blockers

| blocker_id | description | owner | next_action |
|---|---|---|---|
| none |  |  |  |
