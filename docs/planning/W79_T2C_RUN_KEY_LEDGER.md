# W79 T2C Run Key Ledger

| phase | command | run_key | result |
|---|---|---|---|
| baseline | ./bin/ops cap run session.start | CAP-20260228-141034__session.start__Rv5yt47619 | PASS |
| baseline | ./bin/ops cap run loops.status | CAP-20260228-141058__loops.status__Rhqnv54794 | PASS |
| baseline | ./bin/ops cap run gaps.status | CAP-20260228-141058__gaps.status__R4xgu54795 | PASS |
| baseline | ./bin/ops cap run gate.topology.validate | CAP-20260228-141058__gate.topology.validate__Rhrvw54798 | PASS |
| baseline | ./bin/ops cap run verify.route.recommend | CAP-20260228-141058__verify.route.recommend__Riy8n54799 | PASS |
| pre-verify | ./bin/ops cap run calendar.operator.surface | CAP-20260228-142137__calendar.operator.surface__Rv89s68962 | PASS |
| verify | ./bin/ops cap run verify.pack.run core | CAP-20260228-142144__verify.pack.run__Rk5ds69247 | PASS |
| verify | ./bin/ops cap run verify.pack.run secrets | CAP-20260228-142146__verify.pack.run__R35tn70204 | PASS |
| verify | ./bin/ops cap run verify.pack.run workbench | CAP-20260228-142203__verify.pack.run__Rqyy276915 | PASS |
| verify | ./bin/ops cap run verify.pack.run hygiene-weekly | CAP-20260228-142310__verify.pack.run__Rg2pu97524 | PASS |
| verify | ./bin/ops cap run verify.pack.run communications | CAP-20260228-142339__verify.pack.run__R5sos9212 | PASS |
| verify | ./bin/ops cap run verify.pack.run mint | CAP-20260228-142349__verify.pack.run__Rtwvs11354 | PASS |
| verify | ./bin/ops cap run verify.run -- fast | CAP-20260228-142418__verify.run__Rekoq15574 | PASS |
| verify | ./bin/ops cap run verify.run -- domain communications | CAP-20260228-142420__verify.run__Rynap16077 | PASS |
| verify | ./bin/ops cap run verify.freshness.reconcile | CAP-20260228-142439__verify.freshness.reconcile__Rn0pu18441 | PASS |
| verify | ./bin/ops cap run loops.status | CAP-20260228-142541__loops.status__Rexdn37343 | PASS |
| verify | ./bin/ops cap run gaps.status | CAP-20260228-142542__gaps.status__Rl8wh37580 | PASS |
| final | ./bin/ops cap run loops.status | CAP-20260228-142643__loops.status__Ri51141695 | PASS |
| final | ./bin/ops cap run gaps.status | CAP-20260228-142643__gaps.status__R3hb641699 | PASS |
