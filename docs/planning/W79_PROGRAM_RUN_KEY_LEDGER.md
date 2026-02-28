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
