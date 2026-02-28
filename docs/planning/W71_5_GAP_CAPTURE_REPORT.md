# W71.5 Gap Capture Report

Wave: `W71_5_VERIFY_SLIP_GAP_CAPTURE_20260228`
Loop: `LOOP-SPINE-W71-5-VERIFY-SLIP-GAP-CAPTURE-20260228-20260228`

## Reproducibility
| surface | evidence | reproduced | details |
|---|---|---|---|
| D83 proposal marker parity | `CAP-20260228-045633__verify.run__Ryrjm3080` + `/tmp/w71_5_d83_d111_ids_run.log` | yes | `verify.run domain loop_gap` failed (deterministic=2); direct ids-run shows `D83 FAIL` missing `.applied` marker. |
| D111 RAG smoke freshness | `CAP-20260228-045633__verify.run__Rn2uh3083` + `/tmp/w71_5_d83_d111_ids_run.log` | yes | `verify.run domain rag` failed (freshness=1); direct ids-run shows evidence age >24h. |
| media SIGTERM/timeout | `CAP-20260228-045242__verify.pack.run__Rgvx775048` | no | `verify.pack.run media` completed `pass=17 fail=0`, no timeout signature observed. |

## Gap Actions
| gap_id | action | parent_loop | owner | severity | eta | next_action |
|---|---|---|---|---|---|---|
| GAP-OP-1145 | created + normalized | LOOP-SPINE-W71-5-VERIFY-SLIP-GAP-CAPTURE-20260228-20260228 | @ronny | medium | 2026-03-01 | normalize D83 proposal marker reconciliation path |
| GAP-OP-1146 | created + normalized | LOOP-SPINE-W71-5-VERIFY-SLIP-GAP-CAPTURE-20260228-20260228 | @ronny | medium | 2026-03-01 | refresh D111 smoke evidence and recurrence routing |

Media timeout gap creation: not applicable in this wave (not reproducible).
