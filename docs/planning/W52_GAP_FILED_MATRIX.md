# W52 Gap Filed Matrix

Date anchor: 2026-02-27  
Loop: `LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301`

## Summary

- Existing matching open gaps reused: 0
- New canonical gaps filed: 5
- All 5 gaps linked to W52 loop: yes

## Dedupe and Filing Evidence

| Canonical Gap Theme | Dedupe Run Key | Action | Filing Run Key | Resulting Gap ID | Loop Link |
|---|---|---|---|---|---|
| Container OOM exit containment gap | CAP-20260227-040852__gaps.dedupe__Ro6a376973 | filed new | CAP-20260227-040855__gaps.file__R1gmj78185 | GAP-OP-1018 | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 |
| Health probe state-aware policy gap | CAP-20260227-040915__gaps.dedupe__Rr86d80523 | filed new | CAP-20260227-040918__gaps.file__Rad7b80932 | GAP-OP-1019 | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 |
| Image age drift gap (minio stale image policy) | CAP-20260227-040923__gaps.dedupe__Rrc4081414 | filed new | CAP-20260227-040926__gaps.file__Rmxu782022 | GAP-OP-1020 | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 |
| MD1400 capacity monitoring + guard gap | CAP-20260227-040930__gaps.dedupe__Rlp2o82646 | filed new | CAP-20260227-040934__gaps.file__R674384067 | GAP-OP-1021 | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 |
| Credential single-point-of-failure gap | CAP-20260227-040937__gaps.dedupe__R6mje85706 | filed new | CAP-20260227-040942__gaps.file__R04ti88273 | GAP-OP-1022 | LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301 |

## Notes

- `gaps.file` executed with capability-level dedupe checks before each file action.
- `gaps.file` auto-claim behavior is active; claims are expected operational metadata for open gaps.
