# W65 Acceptance Matrix

Wave: LOOP-SPINE-W65-CONTROL-LOOP-COMPLETION-20260228
Status: final
Decision: MERGE_READY

## Baseline vs Final Counters

| metric | baseline | final | delta |
|---|---:|---:|---:|
| open_loops | 17 | 18 | +1 |
| open_gaps | 69 | 54 | -15 |
| orphaned_open_gaps | 0 | 0 | 0 |
| unresolved_freshness_gates | 8 | 2 | -6 |
| gaps_closed_or_fixed_count | 0 | 15 | +15 |

## Acceptance Checks

| id | requirement | actual | result |
|---|---|---|---|
| W65-1 | target 8 freshness gates mapped | D5,D11,D157,D162,D191,D192,D193,D194 mapped in `freshness.reconcile.contract.yaml` | PASS |
| W65-2 | freshness unresolved reduced vs baseline | 8 -> 2 | PASS |
| W65-3 | demotion report generated (report-only) | `W65_GATE_PORTFOLIO_RECOMMENDATIONS.md/.json` generated; no registry auto-mutation | PASS |
| W65-4 | budget gate present + report generated | `D291` registered and `W65_GATE_BUDGET_REPORT.md` generated | PASS |
| W65-5 | closable candidates >=15 with evidence | 20 candidate rows with lock/evidence columns | PASS |
| W65-6 | actual gap closures >=10 | 15 gaps fixed/closed | PASS |
| W65-7 | orphaned_open_gaps = 0 | 0 | PASS |
| W65-8 | required verify block complete | all required run keys captured in this matrix/receipt | PASS |
| W65-9 | no protected-lane mutation | `GAP-OP-973` remains open; protected loops unchanged | PASS |
| W65-10 | no VM/infra runtime mutation | control-plane docs/contracts/scripts + governed read-only checks only | PASS |
| W65-11 | no secret values printed | only references/ids printed; no secret material | PASS |

## Required Run Keys

| check | run_key | result |
|---|---|---|
| session.start | CAP-20260228-011045__session.start__Rmug948278 | PASS |
| loops.status (pre) | CAP-20260228-011109__loops.status__R9izv56366 | PASS |
| gaps.status (pre) | CAP-20260228-011109__gaps.status__R176w56367 | PASS |
| verify.gate_quality.scorecard (pre) | CAP-20260228-011116__verify.gate_quality.scorecard__R4tdd59379 | PASS |
| verify.freshness.reconcile (pre) | CAP-20260228-011116__verify.freshness.reconcile__Rbw2059380 | PASS |
| loops.create (unsupported `--id`) | CAP-20260228-011231__loops.create__Rqbmw72685 | PASS |
| loops.create (fallback) | CAP-20260228-011235__loops.create__Rqiio72960 | PASS |
| gate.topology.validate | CAP-20260228-013304__gate.topology.validate__Rgzcw37216 | PASS |
| verify.route.recommend | CAP-20260228-013304__verify.route.recommend__Rwnn037470 | PASS |
| verify.pack.run core | CAP-20260228-013305__verify.pack.run__Rjcx937718 | PASS |
| verify.pack.run secrets | CAP-20260228-013306__verify.pack.run__R03ox38458 | PASS |
| verify.pack.run communications | CAP-20260228-013321__verify.pack.run__Rmzil45384 | PASS |
| verify.pack.run mint | CAP-20260228-013328__verify.pack.run__R5kx847258 | PASS |
| verify.run fast | CAP-20260228-013346__verify.run__R1waa50423 | PASS |
| verify.run domain communications | CAP-20260228-013348__verify.run__Reiop51182 | PASS |
| verify.freshness.reconcile | CAP-20260228-013406__verify.freshness.reconcile__R3bxx53776 | PASS |
| verify.gate_quality.scorecard | CAP-20260228-013500__verify.gate_quality.scorecard__Rj4h761518 | PASS |
| verify.gate_portfolio.recommendations | CAP-20260228-013501__verify.gate_portfolio.recommendations__R9ya861757 | PASS |
| loops.status (post) | CAP-20260228-013501__loops.status__Ri35c61999 | PASS |
| gaps.status (post) | CAP-20260228-013502__gaps.status__Rd0rg62245 | PASS |
