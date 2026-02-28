# W66/W67 Run Key Ledger

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
loop_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228

| phase | capability | run_key | status | notes |
|---|---|---|---|---|
| phase0 | session.start | CAP-20260228-015151__session.start__Rdwtv92168 | PASS | mandatory startup |
| phase0 | loops.status | CAP-20260228-015211__loops.status__Robm499977 | PASS | baseline loops |
| phase0 | gaps.status | CAP-20260228-015214__gaps.status__R4sz7528 | PASS | baseline gaps |
| phase0 | loops.create --title | CAP-20260228-015218__loops.create__Rneo22191 | FAIL | unsupported flag |
| phase0 | loops.create | CAP-20260228-015223__loops.create__Rjdvo2495 | FAIL | missing --name |
| phase0 | loops.create --id | CAP-20260228-015227__loops.create__Rtrbj2791 | FAIL | unsupported flag |
| phase0 | loops.create --name ... | CAP-20260228-015235__loops.create__R2for3070 | PASS | loop scope created, renamed to canonical id |
| phase1-w66 | gate.topology.validate | CAP-20260228-020104__gate.topology.validate__Rqy8o20660 | PASS | W66 required verify |
| phase1-w66 | verify.route.recommend | CAP-20260228-020107__verify.route.recommend__Ruz0121137 | PASS | W66 required verify |
| phase1-w66 | verify.pack.run core | CAP-20260228-020112__verify.pack.run__Raec621937 | PASS | W66 required verify |
| phase1-w66 | verify.pack.run secrets | CAP-20260228-020116__verify.pack.run__Rwv7b23541 | PASS | W66 required verify |
| phase1-w66 | verify.pack.run communications | CAP-20260228-020135__verify.pack.run__Rp6mt29717 | PASS | W66 required verify |
| phase1-w66 | verify.pack.run mint | CAP-20260228-020149__verify.pack.run__Rz2o531731 | PASS | W66 required verify |
| phase1-w66 | verify.run fast | CAP-20260228-020333__verify.run__Rwz8m56771 | PASS | class-driven wrapper |
| phase1-w66 | verify.run domain communications | CAP-20260228-020338__verify.run__Rsttx57392 | PASS | class-driven wrapper |
| phase1-w66 | docs.projection.sync | CAP-20260228-020401__docs.projection.sync__Rehfg59659 | PASS | projection generation |
| phase1-w66 | docs.projection.verify | CAP-20260228-020408__docs.projection.verify__Rcvyg60165 | PASS | deterministic projection lock |
| phase1-w66 | verify.run fast | CAP-20260228-020213__verify.run__Rznpu35031 | FAIL | parser regression fixed (leading --) |
| phase1-w66 | verify.run fast | CAP-20260228-020231__verify.run__Rnnd436588 | FAIL | over-broad class filter fixed |
| phase2-w67 | gate.topology.validate | CAP-20260228-020420__gate.topology.validate__R7q5s60822 | PASS | W67 required verify |
| phase2-w67 | verify.route.recommend | CAP-20260228-020421__verify.route.recommend__Rw7ek61279 | PASS | W67 required verify |
| phase2-w67 | verify.pack.run core | CAP-20260228-020421__verify.pack.run__Rr5i761699 | PASS | W67 required verify |
| phase2-w67 | verify.pack.run secrets | CAP-20260228-020423__verify.pack.run__R4k7y62574 | PASS | W67 required verify |
| phase2-w67 | verify.pack.run communications | CAP-20260228-020438__verify.pack.run__Rpvgb68570 | PASS | W67 required verify |
| phase2-w67 | verify.pack.run mint | CAP-20260228-020448__verify.pack.run__R5dvi70429 | PASS | W67 required verify |
| phase2-w67 | verify.run fast | CAP-20260228-020506__verify.run__Rbva573756 | PASS | W67 required verify |
| phase2-w67 | verify.run domain communications | CAP-20260228-020507__verify.run__R23zi74232 | PASS | W67 required verify |
| phase2-w67 | verify.gate_quality.scorecard | CAP-20260228-020520__verify.gate_quality.scorecard__Rqyhv76353 | PASS | quality telemetry refresh |
| phase2-w67 | verify.gate_portfolio.recommendations | CAP-20260228-020521__verify.gate_portfolio.recommendations__R56m876586 | PASS | report-only recommendations |
| phase2-w67 | verify.slo.report | CAP-20260228-020522__verify.slo.report__Rpqvh76819 | PASS | command pass, freshness-noise metric fails (report signal) |
| phase2-w67 | verify.freshness.reconcile | CAP-20260228-020522__verify.freshness.reconcile__Rt61g77180 | PASS | reconcile run |
| phase2-w67 | loops.status | CAP-20260228-020842__loops.status__R0ylh87875 | PASS | post-run loops |
| phase2-w67 | gaps.status | CAP-20260228-020842__gaps.status__Resed60821 | PASS | post-run gaps, orphaned=0 |

All run keys above map to `receipts/sessions/RCAP-.../receipt.md`.
