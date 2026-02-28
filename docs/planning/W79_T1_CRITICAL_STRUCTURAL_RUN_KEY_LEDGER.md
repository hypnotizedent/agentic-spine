# W79 T1 Critical Structural Run Key Ledger

| step | command | run_key | result |
|---|---|---|---|
| preflight | ./bin/ops cap run session.start | CAP-20260228-095146__session.start__Rcup615398 | PASS |
| preflight | ./bin/ops cap run loops.status | CAP-20260228-095205__loops.status__Rb74k22308 | PASS |
| preflight | ./bin/ops cap run gaps.status | CAP-20260228-095205__gaps.status__R1vro22719 | PASS |
| preflight | ./bin/ops cap run gate.topology.validate | CAP-20260228-095207__gate.topology.validate__Rxr6x25987 | PASS |
| preflight | ./bin/ops cap run verify.route.recommend | CAP-20260228-095208__verify.route.recommend__R474s15397 | PASS |
| loop | ./bin/ops cap run loops.create --name LOOP-W79-T1-CRITICAL-STRUCTURAL-EXECUTION-20260228-20260228 | CAP-20260228-095922__loops.create__Rbx6q44427 | PASS |
| verify | ./bin/ops cap run gate.topology.validate | CAP-20260228-100524__gate.topology.validate__R6mf021496 | PASS |
| verify | ./bin/ops cap run verify.route.recommend | CAP-20260228-100524__verify.route.recommend__R48ig21769 | PASS |
| verify | ./bin/ops cap run verify.pack.run core | CAP-20260228-100525__verify.pack.run__R87xx22052 | PASS |
| verify | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-100526__verify.pack.run__Rjds323119 | PASS |
| verify | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-100544__verify.pack.run__Rlfud31590 | PASS |
| verify | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-100648__verify.pack.run__Rkq4f55540 | PASS |
| verify | ./bin/ops cap run verify.pack.run communications | CAP-20260228-100737__verify.pack.run__Ruv8c70346 | PASS |
| verify | ./bin/ops cap run verify.pack.run mint | CAP-20260228-100746__verify.pack.run__Rxr6g72363 | PASS |
| verify | ./bin/ops cap run verify.run -- fast | CAP-20260228-100813__verify.run__Ryvwy76776 | PASS |
| verify | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-100815__verify.run__Rofp277265 | PASS |
| verify | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-100825__verify.freshness.reconcile__Ry6qb79807 | PASS |
| verify | ./bin/ops cap run loops.status | CAP-20260228-100924__loops.status__R178w92675 | PASS |
| verify | ./bin/ops cap run gaps.status | CAP-20260228-100925__gaps.status__Rqaat92925 | PASS |
| post | ./bin/ops cap run loops.status | CAP-20260228-101247__loops.status__Rx58t11531 | PASS |
| post | ./bin/ops cap run gaps.status | CAP-20260228-101247__gaps.status__Rttrk11546 | PASS |
