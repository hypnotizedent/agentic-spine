# W79 T1B/T2 Run Key Ledger

| phase | command | run_key | result |
|---|---|---|---|
| baseline | ./bin/ops cap run session.start | CAP-20260228-102441__session.start__R6w3657727 | PASS |
| baseline | ./bin/ops cap run loops.status | CAP-20260228-102501__loops.status__R1oti64878 | PASS |
| baseline | ./bin/ops cap run gaps.status | CAP-20260228-102501__gaps.status__Rv2v765305 | PASS |
| baseline | ./bin/ops cap run gate.topology.validate | CAP-20260228-102504__gate.topology.validate__Rlgq168240 | PASS |
| baseline | ./bin/ops cap run verify.route.recommend | CAP-20260228-102504__verify.route.recommend__Rhkul68501 | PASS |
| verify | ./bin/ops cap run verify.pack.run core | CAP-20260228-102827__verify.pack.run__Rr1hz72555 | PASS |
| verify | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-102829__verify.pack.run__Rhj4773445 | PASS |
| verify | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-102846__verify.pack.run__Rsoz680363 | PASS |
| verify | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-102952__verify.pack.run__Rqlyn1483 | PASS |
| verify | ./bin/ops cap run verify.pack.run communications | CAP-20260228-103019__verify.pack.run__Rwraj12576 | PASS |
| verify | ./bin/ops cap run verify.pack.run mint | CAP-20260228-103028__verify.pack.run__Rwe2k14669 | PASS |
| verify | ./bin/ops cap run verify.run -- fast | CAP-20260228-103107__verify.run__R5hr720081 | PASS |
| verify | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-103109__verify.run__Rqwp320571 | PASS |
| verify | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-103122__verify.freshness.reconcile__R0lxp22983 | PASS |
| verify | ./bin/ops cap run loops.status | CAP-20260228-103235__loops.status__R0ehg31772 | PASS |
| verify | ./bin/ops cap run gaps.status | CAP-20260228-103235__gaps.status__Rt0xb32019 | PASS |
