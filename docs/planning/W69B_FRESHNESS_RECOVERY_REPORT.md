# W69B Freshness Recovery Report

wave_id: W69B_FRESHNESS_RECOVERY_AND_FINAL_PROMOTION_20260228
loop_id: LOOP-W69B-FRESHNESS-RECOVERY-AND-FINAL-PROMOTION-20260228

## Baseline (Before Recovery)

- baseline run: `CAP-20260228-034006__verify.pack.run__Rw39e79068`
- baseline freshness failing set: `D188, D191, D192, D193, D194`

## Recovery Sequence (Attempt 1)

1. `CAP-20260228-034053__domain-inventory-refresh__Rz1iz90282` (done)
2. `CAP-20260228-034251__media-content-snapshot-refresh__Rt1gh94851` (done)
3. `CAP-20260228-034359__ha-inventory-snapshot-build__Rxtdo96467` (done)
4. `CAP-20260228-034400__network-inventory-snapshot-build__Rntvq96751` (done)
5. `CAP-20260228-034401__verify.freshness.reconcile__R0mwl96997` (done)
6. `CAP-20260228-034701__verify.pack.run__Rwzfa6953` hygiene-weekly (done)

## Freshness Outcome

- post-recovery freshness set in hygiene-weekly: no failures in `D188/D191/D192/D193/D194`
- verification evidence:
  - `D188 PASS`
  - `D191 PASS`
  - `D192 PASS`
  - `D193 PASS`
  - `D194 PASS`

## Retry Policy Result

- Retry after 5 minutes: `not required` (attempt 1 cleared the blocker set).
