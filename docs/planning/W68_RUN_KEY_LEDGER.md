# W68 Run Key Ledger

wave_id: LOOP-SPINE-W68-OUTCOME-BURNDOWN-20260228-20260228

| phase | command | run_key | status | note |
|---|---|---|---|---|
| 0 | session.start | CAP-20260228-023447__session.start__Rsmad13633 | PASS | baseline startup |
| 0 | loops.status (pre) | CAP-20260228-023507__loops.status__Rzzwe20027 | PASS | baseline counters |
| 0 | gaps.status (pre) | CAP-20260228-023509__gaps.status__Rr5nc20271 | PASS | baseline counters |
| 0 | verify.gate_quality.scorecard (pre) | CAP-20260228-023513__verify.gate_quality.scorecard__Rwvnz21577 | PASS | baseline telemetry |
| 0 | verify.freshness.reconcile (pre) | CAP-20260228-023517__verify.freshness.reconcile__R2p8021817 | PASS | baseline unresolved freshness=1 |
| 0 | loops.create --title (unsupported) | CAP-20260228-023812__loops.create__Roqlk31887 | FAIL | arg unsupported |
| 0 | loops.create (missing args) | CAP-20260228-023816__loops.create__Rpf7d32158 | FAIL | objective required |
| 0 | loops.create --name only | CAP-20260228-023818__loops.create__Raty832427 | FAIL | objective required |
| 0 | loops.create (fallback success) | CAP-20260228-023821__loops.create__Rcy5432698 | PASS | loop scope created then normalized to requested ID |
| 1 | loops.list --open | CAP-20260228-023844__loops.list__Rz28u33763 | PASS | candidate discovery |
| 2 | loop.closeout.finalize W64 | CAP-20260228-024357__loop.closeout.finalize__Rdc1161897 | PASS | loop closed |
| 2 | loop.closeout.finalize W65 | CAP-20260228-024402__loop.closeout.finalize__Rmkse64007 | PASS | loop closed |
| 2 | loop.closeout.finalize W66/W67 | CAP-20260228-024406__loop.closeout.finalize__Rfl7d64356 | PASS | loop closed |
| 2 | loop.closeout.finalize W61 (initial) | CAP-20260228-024410__loop.closeout.finalize__Ru8o365322 | FAIL | linked-gap mutation path error; one gap (`GAP-OP-1097`) moved to fixed before failure |
| 2 | loop.closeout.finalize W61 (reconcile) | CAP-20260228-024418__loop.closeout.finalize__Rgmzz65804 | PASS | loop closed with `--no-close-linked-gaps` |
| 2 | gaps.close GAP-OP-1100 | CAP-20260228-024509__gaps.close__Rouf370771 | PASS | closed |
| 2 | gaps.close GAP-OP-1048 | CAP-20260228-024511__gaps.close__Rrzyb71364 | PASS | closed |
| 2 | gaps.close GAP-OP-1057 | CAP-20260228-024513__gaps.close__Ro7bb71974 | PASS | closed |
| 2 | gaps.close GAP-OP-1059 | CAP-20260228-024515__gaps.close__R6dco72963 | PASS | closed |
| 2 | gaps.close GAP-OP-1060 | CAP-20260228-024517__gaps.close__Rcob774298 | PASS | closed |
| 2 | gaps.close GAP-OP-1075 | CAP-20260228-024525__gaps.close__R8qie78248 | PASS | closed |
| 2 | gaps.close GAP-OP-1079 | CAP-20260228-024527__gaps.close__Rd8hx79562 | PASS | closed |
| 2 | gaps.close GAP-OP-1080 | CAP-20260228-024529__gaps.close__R1l6p80817 | PASS | closed |
| 2 | gaps.close GAP-OP-1081 | CAP-20260228-024532__gaps.close__Ri5yq82153 | PASS | closed |
| 2 | gaps.close GAP-OP-1082 | CAP-20260228-024534__gaps.close__Rtwjv83567 | PASS | closed |
| 2 | gaps.close GAP-OP-1084 | CAP-20260228-024541__gaps.close__Ry1m986991 | PASS | closed |
| 2 | gaps.close GAP-OP-1085 | CAP-20260228-024543__gaps.close__Rq6uw88384 | PASS | closed |
| 2 | gaps.close GAP-OP-1089 | CAP-20260228-024545__gaps.close__Rn8ni89674 | PASS | closed |
| 3 | gate.topology.validate | CAP-20260228-024554__gate.topology.validate__Rwkfj93438 | PASS | required block |
| 3 | verify.route.recommend | CAP-20260228-024557__verify.route.recommend__Rovis94944 | PASS | required block |
| 3 | verify.pack.run core | CAP-20260228-024600__verify.pack.run__Rm8a795716 | PASS | required block |
| 3 | verify.pack.run secrets | CAP-20260228-024603__verify.pack.run__R7cro98881 | PASS | required block |
| 3 | verify.pack.run communications | CAP-20260228-024629__verify.pack.run__Rq5t913358 | PASS | required block |
| 3 | verify.pack.run mint | CAP-20260228-024643__verify.pack.run__Rtetm15560 | PASS | required block |
| 3 | verify.run -- fast | CAP-20260228-024715__verify.run__Rplxf20817 | PASS | required block |
| 3 | verify.run -- domain communications | CAP-20260228-024719__verify.run__Rvju621309 | PASS | required block |
| 3 | verify.freshness.reconcile | CAP-20260228-024736__verify.freshness.reconcile__Rbm0m23456 | PASS | required block, unresolved freshness=1 |
| 3 | verify.gate_quality.scorecard | CAP-20260228-024848__verify.gate_quality.scorecard__Rh70n32678 | PASS | required block |
| 3 | loops.status (post) | CAP-20260228-024852__loops.status__Rzoh633885 | PASS | final counters |
| 3 | gaps.status (post) | CAP-20260228-024855__gaps.status__Rv4ir34187 | PASS | final counters |
| 3 | verify.run -- domain loop_gap | CAP-20260228-024904__verify.run__R2ffm36736 | FAIL | optional diagnostic; not in required block |
| 3 | verify.slo.report | CAP-20260228-024922__verify.slo.report__R623u40592 | PASS | W68 outcome SLO artifact input |
