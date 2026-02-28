# W71.5 Acceptance Matrix

| id | requirement | result | evidence |
|---|---|---|---|
| A1 | D83 gap captured with evidence | PASS | GAP-OP-1145 + `CAP-20260228-045633__verify.run__Ryrjm3080` |
| A2 | D111 gap captured with evidence | PASS | GAP-OP-1146 + `CAP-20260228-045633__verify.run__Rn2uh3083` |
| A3 | media timeout gap captured iff reproducible | PASS | media not reproducible (`CAP-20260228-045242__verify.pack.run__Rgvx775048` pass=17 fail=0); no media-timeout gap opened |
| A4 | orphaned_open_gaps remains 0 | PASS | `CAP-20260228-045708__gaps.status__R1fvd6614` |
| A5 | parity local=origin=github/share | PASS | `docs/planning/W71_5_PROMOTION_PARITY_RECEIPT.md` |
| A6 | clean branch status | PASS | `docs/planning/W71_5_BRANCH_ZERO_STATUS_REPORT.md` |
| A7 | attestations true | PASS | W71.5 supervisor receipt |
