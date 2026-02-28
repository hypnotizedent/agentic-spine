# W79 T2 High Structural Run Key Ledger

| phase | command | run_key | result |
|---|---|---|---|
| baseline | ./bin/ops cap run session.start | CAP-20260228-103947__session.start__Ranb852799 | PASS |
| baseline | ./bin/ops cap run loops.status | CAP-20260228-104004__loops.status__Rh0dc58877 | PASS |
| baseline | ./bin/ops cap run gaps.status | CAP-20260228-104004__gaps.status__Rxubg59479 | PASS |
| baseline | ./bin/ops cap run gate.topology.validate | CAP-20260228-104007__gate.topology.validate__Rmnt463503 | PASS |
| baseline | ./bin/ops cap run verify.route.recommend | CAP-20260228-104007__verify.route.recommend__Rv0pz63978 | PASS |
| baseline | ./bin/ops cap run loops.create --name LOOP-W79-T2-HIGH-STRUCTURAL-EXECUTION-20260228-20260228 --objective "Execute high structural tranche for W79 T2" | CAP-20260228-104008__loops.create__Rdlg464415 | PASS |
| verify | ./bin/ops cap run verify.pack.run core | CAP-20260228-104607__verify.pack.run__Rxny274096 | PASS |
| verify | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-104608__verify.pack.run__R7ucq74968 | PASS |
| verify | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-104626__verify.pack.run__Rzvoo81997 | PASS |
| verify | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-104725__verify.pack.run__Rklq44490 | PASS |
| verify | ./bin/ops cap run verify.pack.run communications | CAP-20260228-104811__verify.pack.run__R5nlz16964 | PASS |
| verify | ./bin/ops cap run verify.pack.run mint | CAP-20260228-104825__verify.pack.run__Rad9819332 | PASS |
| verify | ./bin/ops cap run verify.run -- fast | CAP-20260228-104912__verify.run__Rrfsf23851 | PASS |
| verify | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-104913__verify.run__Rgzyy24333 | PASS |
| verify | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-104935__verify.freshness.reconcile__Rnsm828785 | PASS |
| verify | ./bin/ops cap run loops.status | CAP-20260228-105156__loops.status__R3cmz41649 | PASS |
| verify | ./bin/ops cap run gaps.status | CAP-20260228-105156__gaps.status__Rjc2f41650 | PASS |
