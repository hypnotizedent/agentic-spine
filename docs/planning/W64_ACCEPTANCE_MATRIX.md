# W64 Acceptance Matrix

Wave: LOOP-SPINE-W64-BACKLOG-THROUGHPUT-CLOSURE-20260228
Status: final
Decision: MERGE_READY

## Baseline -> Final Counters

| metric | baseline | final | delta | target | result |
|---|---:|---:|---:|---|---|
| open_loops | 21 | 17 | -4 | close >=5 ready loops | PASS |
| open_gaps | 80 | 69 | -11 | reduce by >=10 | PASS |
| orphaned_open_gaps | 0 | 0 | 0 | must remain 0 | PASS |
| loops_closed_count | 0 | 5 | +5 | >=5 | PASS |
| gaps_closed_or_fixed_count | 0 | 11 | +11 | >=10 | PASS |

## Required Run Keys

| check | run_key | result |
|---|---|---|
| session.start | CAP-20260228-004132__session.start__Rdn3j76505 | PASS |
| loops.status (pre) | CAP-20260228-004154__loops.status__R1a3s83605 | PASS |
| gaps.status (pre) | CAP-20260228-004154__gaps.status__Rqsvm83606 | PASS |
| loops.create (requested `--id`, unsupported) | CAP-20260228-004158__loops.create__Rk5iz85529 | PASS (fallback used) |
| loops.create (W64 loop created) | CAP-20260228-004209__loops.create__Rdwqj85961 | PASS |
| gate.topology.validate | CAP-20260228-004926__gate.topology.validate__Rhbuh1899 | PASS |
| verify.route.recommend | CAP-20260228-004927__verify.route.recommend__R4yk02388 | PASS |
| verify.pack.run core | CAP-20260228-004927__verify.pack.run__R120b2681 | PASS |
| verify.pack.run secrets | CAP-20260228-004929__verify.pack.run__Rgtbt3423 | PASS |
| verify.pack.run communications | CAP-20260228-004944__verify.pack.run__Risf59433 | PASS |
| verify.pack.run mint | CAP-20260228-004951__verify.pack.run__Rvgj511294 | PASS |
| verify.run fast | CAP-20260228-005028__verify.run__R567z14961 | PASS |
| verify.run domain communications | CAP-20260228-005030__verify.run__Raaiz16003 | PASS |
| loops.status (post) | CAP-20260228-005044__loops.status__Rbfb318449 | PASS |
| gaps.status (post) | CAP-20260228-005045__gaps.status__Rckck18693 | PASS |

## Binary Acceptance

| id | requirement | actual | result |
|---|---|---|---|
| W64-1 | loops_closed_count >= 5 | 5 loops closed via `loop.closeout.finalize` | PASS |
| W64-2 | open_gaps reduced by >=10 | 80 -> 69 (`-11`) | PASS |
| W64-3 | orphaned_open_gaps = 0 | post gaps.status orphaned=0 | PASS |
| W64-4 | required verify block complete | all required run keys captured and done | PASS |
| W64-5 | no protected-lane mutation | protected loops/gaps unchanged | PASS |
| W64-6 | no VM/infra runtime mutation | control-plane docs/contracts/state only | PASS |
| W64-7 | no secret values printed | only key names/ids referenced | PASS |
