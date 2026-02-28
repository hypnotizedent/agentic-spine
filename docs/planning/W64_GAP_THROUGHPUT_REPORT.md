# W64 Gap Throughput Report

Wave: LOOP-SPINE-W64-BACKLOG-THROUGHPUT-CLOSURE-20260228

Summary:
- open_gaps baseline: 80
- open_gaps final: 69
- delta: -11
- throughput_target: reduce by >=10
- result: PASS

| gap_id | pre_status | post_status | closure_basis | blocker_reason |
|---|---|---|---|---|
| GAP-OP-1088 | open | fixed | `gaps.file` lock retry + single-lock batch behavior verified in active script path | none |
| GAP-OP-1090 | open | fixed | `gaps.file` supports `--parent-loop/--loop` in active runtime path | none |
| GAP-OP-1091 | open | fixed | `--id auto` + `gaps.next-id` helper present and callable | none |
| GAP-OP-1094 | open | fixed | batch path appends under a single lock, preventing interleaving behavior | none |
| GAP-OP-1101 | open | fixed | yq batch root detection compatibility fix present in active script | none |
| GAP-OP-1092 | open | fixed | `loops.create` template normalized to Step vocabulary | none |
| GAP-OP-1093 | open | fixed | canonical workflow moved to capability-only mutation with lock/retry path | none |
| GAP-OP-1095 | open | fixed | `cap show` now exposes modes/flags/examples for high-friction capability surfaces | none |
| GAP-OP-1096 | open | fixed | capability command includes mode auto-injection pattern | none |
| GAP-OP-1098 | open | closed | historical MEMORY artifact dependency retired from active operator flow | none |
| GAP-OP-1099 | open | fixed | `gaps.file --batch` + lock wait controls reduce sequential filing overhead | none |
