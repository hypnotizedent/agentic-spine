# W79 Program Run Key Ledger

| phase | command | run_key | result |
|---|---|---|---|
| 0 | ./bin/ops cap run session.start | CAP-20260228-091342__session.start__Rw9dv11049 | PASS |
| 0 | ./bin/ops cap run loops.status | CAP-20260228-091358__loops.status__Rwt5q16896 | PASS |
| 0 | ./bin/ops cap run gaps.status | CAP-20260228-091359__gaps.status__Rhg7217326 | PASS |
| 0 | ./bin/ops cap run gate.topology.validate | CAP-20260228-091401__gate.topology.validate__Raobx19970 | PASS |
| 0 | ./bin/ops cap run verify.route.recommend | CAP-20260228-091402__verify.route.recommend__Rhopn20436 | PASS |
| 1 | ./bin/ops cap run loops.create --name W79-PROGRAM... | CAP-20260228-091418__loops.create__Rnq1122748 | PASS |
| 2 | ./bin/ops cap run loops.create --name W79-T0-SECURITY-EMERGENCY | CAP-20260228-091737__loops.create__Rhcoe54625 | PASS |
| 2 | ./bin/ops cap run loops.create --name W79-T1-CRITICAL-STRUCTURAL | CAP-20260228-091738__loops.create__Ruemg54905 | PASS |
| 2 | ./bin/ops cap run loops.create --name W79-T2-HIGH-STRUCTURAL | CAP-20260228-091738__loops.create__Rwdhn55185 | PASS |
| 2 | ./bin/ops cap run loops.create --name W79-T3-MEDIUM-LOW-COSMETIC | CAP-20260228-091739__loops.create__Raz7h54624 | PASS |
| 1 | ./bin/ops cap run gaps.file --from-file /tmp/w79_gaps_batch.yaml --no-commit | CAP-20260228-091855__gaps.file__Ruvps57422 | PASS |
| 1 | ./bin/ops cap run loops.status (post-registration) | CAP-20260228-092136__loops.status__Rkmvr69063 | PASS |
| 1 | ./bin/ops cap run gaps.status (post-registration) | CAP-20260228-092136__gaps.status__Rngdf69066 | PASS |
| 1 | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-092156__verify.freshness.reconcile__Rgzqf72203 | PASS |
| 3 | ./bin/ops cap run gate.topology.validate | CAP-20260228-092443__gate.topology.validate__Rgo8583369 | PASS |
| 3 | ./bin/ops cap run verify.route.recommend | CAP-20260228-092444__verify.route.recommend__Rt4p783621 | PASS |
| 3 | ./bin/ops cap run verify.pack.run core | CAP-20260228-092444__verify.pack.run__Rtnn983867 | PASS |
| 3 | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-092446__verify.pack.run__Rqwon84644 | PASS |
| 3 | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-092503__verify.pack.run__Rmnwv90688 | FAIL (D79 unregistered script) |
| 3 | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-092603__verify.pack.run__Rzda211360 | PASS |
| 3 | ./bin/ops cap run verify.pack.run communications | CAP-20260228-092627__verify.pack.run__R6nb924250 | PASS |
| 3 | ./bin/ops cap run verify.pack.run mint | CAP-20260228-092635__verify.pack.run__Ri64o30652 | PASS |
| 3 | ./bin/ops cap run verify.run -- fast | CAP-20260228-092703__verify.run__Rc0qu39004 | PASS |
| 3 | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-092705__verify.run__Rswss39478 | PASS |
| 3 | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-092713__verify.freshness.reconcile__Rpig941745 | PASS |
| 3 | ./bin/ops cap run loops.status (post-verify) | CAP-20260228-092802__loops.status__Rh0d749199 | PASS |
| 3 | ./bin/ops cap run gaps.status (post-verify) | CAP-20260228-092803__gaps.status__Rut1u83368 | PASS |
| 3 | ./bin/ops cap run verify.pack.run workbench (after D79 allowlist patch) | CAP-20260228-092834__verify.pack.run__Rnl7252473 | PASS |
| T1-pre | ./bin/ops cap run session.start | CAP-20260228-095146__session.start__Rcup615398 | PASS |
| T1-pre | ./bin/ops cap run loops.status | CAP-20260228-095205__loops.status__Rb74k22308 | PASS |
| T1-pre | ./bin/ops cap run gaps.status | CAP-20260228-095205__gaps.status__R1vro22719 | PASS |
| T1-pre | ./bin/ops cap run gate.topology.validate | CAP-20260228-095207__gate.topology.validate__Rxr6x25987 | PASS |
| T1-pre | ./bin/ops cap run verify.route.recommend | CAP-20260228-095208__verify.route.recommend__R474s15397 | PASS |
| T1-pre | ./bin/ops cap run loops.create --name LOOP-W79-T1-CRITICAL-STRUCTURAL-EXECUTION-20260228-20260228 | CAP-20260228-095922__loops.create__Rbx6q44427 | PASS |
| T1 | ./bin/ops cap run gate.topology.validate | CAP-20260228-100524__gate.topology.validate__R6mf021496 | PASS |
| T1 | ./bin/ops cap run verify.route.recommend | CAP-20260228-100524__verify.route.recommend__R48ig21769 | PASS |
| T1 | ./bin/ops cap run verify.pack.run core | CAP-20260228-100525__verify.pack.run__R87xx22052 | PASS |
| T1 | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-100526__verify.pack.run__Rjds323119 | PASS |
| T1 | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-100544__verify.pack.run__Rlfud31590 | PASS |
| T1 | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-100648__verify.pack.run__Rkq4f55540 | PASS |
| T1 | ./bin/ops cap run verify.pack.run communications | CAP-20260228-100737__verify.pack.run__Ruv8c70346 | PASS |
| T1 | ./bin/ops cap run verify.pack.run mint | CAP-20260228-100746__verify.pack.run__Rxr6g72363 | PASS |
| T1 | ./bin/ops cap run verify.run -- fast | CAP-20260228-100813__verify.run__Ryvwy76776 | PASS |
| T1 | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-100815__verify.run__Rofp277265 | PASS |
| T1 | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-100825__verify.freshness.reconcile__Ry6qb79807 | PASS |
| T1 | ./bin/ops cap run loops.status | CAP-20260228-100924__loops.status__R178w92675 | PASS |
| T1 | ./bin/ops cap run gaps.status | CAP-20260228-100925__gaps.status__Rqaat92925 | PASS |
| T1-post | ./bin/ops cap run loops.status | CAP-20260228-101247__loops.status__Rx58t11531 | PASS |
| T1-post | ./bin/ops cap run gaps.status | CAP-20260228-101247__gaps.status__Rttrk11546 | PASS |
| T1B/T2 | ./bin/ops cap run session.start | CAP-20260228-102441__session.start__R6w3657727 | PASS |
| T1B/T2 | ./bin/ops cap run loops.status | CAP-20260228-102501__loops.status__R1oti64878 | PASS |
| T1B/T2 | ./bin/ops cap run gaps.status | CAP-20260228-102501__gaps.status__Rv2v765305 | PASS |
| T1B/T2 | ./bin/ops cap run gate.topology.validate | CAP-20260228-102504__gate.topology.validate__Rlgq168240 | PASS |
| T1B/T2 | ./bin/ops cap run verify.route.recommend | CAP-20260228-102504__verify.route.recommend__Rhkul68501 | PASS |
| T1B/T2 | ./bin/ops cap run verify.pack.run core | CAP-20260228-102827__verify.pack.run__Rr1hz72555 | PASS |
| T1B/T2 | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-102829__verify.pack.run__Rhj4773445 | PASS |
| T1B/T2 | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-102846__verify.pack.run__Rsoz680363 | PASS |
| T1B/T2 | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-102952__verify.pack.run__Rqlyn1483 | PASS |
| T1B/T2 | ./bin/ops cap run verify.pack.run communications | CAP-20260228-103019__verify.pack.run__Rwraj12576 | PASS |
| T1B/T2 | ./bin/ops cap run verify.pack.run mint | CAP-20260228-103028__verify.pack.run__Rwe2k14669 | PASS |
| T1B/T2 | ./bin/ops cap run verify.run -- fast | CAP-20260228-103107__verify.run__R5hr720081 | PASS |
| T1B/T2 | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-103109__verify.run__Rqwp320571 | PASS |
| T1B/T2 | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-103122__verify.freshness.reconcile__R0lxp22983 | PASS |
| T1B/T2 | ./bin/ops cap run loops.status | CAP-20260228-103235__loops.status__R0ehg31772 | PASS |
| T1B/T2 | ./bin/ops cap run gaps.status | CAP-20260228-103235__gaps.status__Rt0xb32019 | PASS |
| T2-high | ./bin/ops cap run session.start | CAP-20260228-103947__session.start__Ranb852799 | PASS |
| T2-high | ./bin/ops cap run loops.status | CAP-20260228-104004__loops.status__Rh0dc58877 | PASS |
| T2-high | ./bin/ops cap run gaps.status | CAP-20260228-104004__gaps.status__Rxubg59479 | PASS |
| T2-high | ./bin/ops cap run gate.topology.validate | CAP-20260228-104007__gate.topology.validate__Rmnt463503 | PASS |
| T2-high | ./bin/ops cap run verify.route.recommend | CAP-20260228-104007__verify.route.recommend__Rv0pz63978 | PASS |
| T2-high | ./bin/ops cap run loops.create --name LOOP-W79-T2-HIGH-STRUCTURAL-EXECUTION-20260228-20260228 --objective \"Execute high structural tranche for W79 T2\" | CAP-20260228-104008__loops.create__Rdlg464415 | PASS |
| T2-high | ./bin/ops cap run verify.pack.run core | CAP-20260228-104607__verify.pack.run__Rxny274096 | PASS |
| T2-high | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-104608__verify.pack.run__R7ucq74968 | PASS |
| T2-high | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-104626__verify.pack.run__Rzvoo81997 | PASS |
| T2-high | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-104725__verify.pack.run__Rklq44490 | PASS |
| T2-high | ./bin/ops cap run verify.pack.run communications | CAP-20260228-104811__verify.pack.run__R5nlz16964 | PASS |
| T2-high | ./bin/ops cap run verify.pack.run mint | CAP-20260228-104825__verify.pack.run__Rad9819332 | PASS |
| T2-high | ./bin/ops cap run verify.run -- fast | CAP-20260228-104912__verify.run__Rrfsf23851 | PASS |
| T2-high | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-104913__verify.run__Rgzyy24333 | PASS |
| T2-high | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-104935__verify.freshness.reconcile__Rnsm828785 | PASS |
| T2-high | ./bin/ops cap run loops.status | CAP-20260228-105156__loops.status__R3cmz41649 | PASS |
| T2-high | ./bin/ops cap run gaps.status | CAP-20260228-105156__gaps.status__Rjc2f41650 | PASS |
