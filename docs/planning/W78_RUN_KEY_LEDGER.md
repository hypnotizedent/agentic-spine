# W78 Run Key Ledger

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228

| phase | command | run_key | result |
|---|---|---|---|
| 0 | `./bin/ops cap run session.start` | `CAP-20260228-081005__session.start__Rfilm4028` | PASS |
| 0 | `./bin/ops cap run loops.status` | `CAP-20260228-081028__loops.status__Rvggz11305` | PASS |
| 0 | `./bin/ops cap run gaps.status` | `CAP-20260228-081028__gaps.status__R6y7911307` | PASS |
| 0 | `./bin/ops cap run gate.topology.validate` | `CAP-20260228-081028__gate.topology.validate__Rcw7e11313` | PASS |
| 0 | `./bin/ops cap run verify.route.recommend` | `CAP-20260228-081028__verify.route.recommend__Rwb1711315` | PASS |
| 0 | `./bin/ops cap run loops.create ...` | `CAP-20260228-081032__loops.create__Rhwrp14029` | PASS |
| 0 | `./bin/ops cap run verify.freshness.reconcile` | `CAP-20260228-081243__verify.freshness.reconcile__Rqggx21308` | PASS |
| 2 | `./bin/ops cap run docs.projection.sync` | `CAP-20260228-082452__docs.projection.sync__R27925588` | PASS |
| 2 | `./bin/ops cap run mint.live.baseline.status` | `CAP-20260228-082522__mint.live.baseline.status__Rswz77400` | PASS |
| 3 | `./bin/ops cap run gate.topology.validate` | `CAP-20260228-082820__gate.topology.validate__Rcary40111` | PASS |
| 3 | `./bin/ops cap run verify.route.recommend` | `CAP-20260228-082820__verify.route.recommend__Rnfdp40423` | PASS |
| 3 | `./bin/ops cap run verify.pack.run core` | `CAP-20260228-082821__verify.pack.run__Redpt40680` | FAIL (D148) |
| 3 | `./bin/ops cap run verify.pack.run secrets` | `CAP-20260228-082822__verify.pack.run__Rdqhp41558` | PASS |
| 3 | `./bin/ops cap run verify.pack.run workbench` | `CAP-20260228-082840__verify.pack.run__R8wme49819` | FAIL (D148) |
| 3 | `./bin/ops cap run verify.pack.run hygiene-weekly` | `CAP-20260228-082937__verify.pack.run__R9t3o74492` | PASS |
| 3 | `./bin/ops cap run verify.pack.run communications` | `CAP-20260228-082958__verify.pack.run__Rmloq85200` | FAIL (D148) |
| 3 | `./bin/ops cap run verify.pack.run mint` | `CAP-20260228-083005__verify.pack.run__Ryyf687266` | PASS |
| 3 | `./bin/ops cap run verify.run -- fast` | `CAP-20260228-083032__verify.run__R3ry891170` | PASS |
| 3 | `./bin/ops cap run verify.run -- domain communications` | `CAP-20260228-083034__verify.run__R63qz91655` | FAIL (freshness=1 via D148) |
| 3 | `./bin/ops cap run verify.freshness.reconcile` | `CAP-20260228-083041__verify.freshness.reconcile__Rlshg93863` | PASS (`unresolved_count=1`) |
| 3 | `./bin/ops cap run loops.status` | `CAP-20260228-083126__loops.status__R17r92016` | PASS |
| 3 | `./bin/ops cap run gaps.status` | `CAP-20260228-083126__gaps.status__Rrasq2305` | PASS |
| 3 | `./bin/ops cap run docs.projection.verify` | `CAP-20260228-083306__docs.projection.verify__R2qg26571` | PASS |
| W78B-0 | `./bin/ops cap run session.start` | `CAP-20260228-090415__session.start__Ry1dk59222` | PASS |
| W78B-0 | `./bin/ops cap run verify.pack.run core` | `CAP-20260228-090434__verify.pack.run__Rvsxo65515` | FAIL (baseline D148) |
| W78B-1 | `./bin/ops cap run host.launchagents.sync` | `CAP-20260228-090443__host.launchagents.sync__Rj91767935` | BLOCKED (manual approval required) |
| W78B-1 | `./ops/plugins/host/bin/host-launchagents-sync --label ...` | n/a (direct governed script) | PASS |
| W78B-2 | `./bin/ops cap run verify.pack.run core` | `CAP-20260228-090506__verify.pack.run__Rpcdv68723` | PASS |
| W78B-2 | `./bin/ops cap run verify.pack.run workbench` | `CAP-20260228-090507__verify.pack.run__Rs05h69505` | PASS |
| W78B-2 | `./bin/ops cap run verify.pack.run communications` | `CAP-20260228-090620__verify.pack.run__Ru1kk89380` | PASS |
| W78B-2 | `./bin/ops cap run verify.run -- domain communications` | `CAP-20260228-090633__verify.run__Rz2f491470` | PASS |
| W78B-2 | `./bin/ops cap run verify.freshness.reconcile` | `CAP-20260228-090642__verify.freshness.reconcile__R1l9w93718` | PASS (`unresolved_count=0`) |
| W78B-2 | `./bin/ops cap run loops.status` | `CAP-20260228-090752__loops.status__R12wz2784` | PASS |
| W78B-2 | `./bin/ops cap run gaps.status` | `CAP-20260228-090752__gaps.status__Rkr6d3030` | PASS |
