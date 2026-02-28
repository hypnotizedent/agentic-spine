# W69B Run Key Ledger

wave_id: W69B_FRESHNESS_RECOVERY_AND_FINAL_PROMOTION_20260228

## Phase 0 Preflight

| command | run_key | status |
|---|---|---|
| `session.start` | `CAP-20260228-033923__session.start__Rlr5m69818` | done |
| `loops.status` (pre) | `CAP-20260228-033923__loops.status__R3b9l69827` | done |
| `gaps.status` (pre) | `CAP-20260228-033923__gaps.status__Rb6vq69851` | done |
| `loops.create` (failed arg style) | `CAP-20260228-033946__loops.create__Rpo7y77431` | failed |
| `loops.create --help` | `CAP-20260228-033951__loops.create__Ro2i177725` | done |
| `loops.create` (W69B loop) | `CAP-20260228-033958__loops.create__Rh40v78065` | done |

## Baseline Freshness Truth Check

| command | run_key | status |
|---|---|---|
| `verify.pack.run hygiene-weekly` (baseline) | `CAP-20260228-034006__verify.pack.run__Rw39e79068` | failed |

## Phase 1 Freshness Recovery (Attempt 1)

| command | run_key | status |
|---|---|---|
| `domain-inventory-refresh -- --once` | `CAP-20260228-034053__domain-inventory-refresh__Rz1iz90282` | done |
| `media-content-snapshot-refresh` | `CAP-20260228-034251__media-content-snapshot-refresh__Rt1gh94851` | done |
| `ha-inventory-snapshot-build` | `CAP-20260228-034359__ha-inventory-snapshot-build__Rxtdo96467` | done |
| `network-inventory-snapshot-build` | `CAP-20260228-034400__network-inventory-snapshot-build__Rntvq96751` | done |
| `verify.freshness.reconcile` | `CAP-20260228-034401__verify.freshness.reconcile__R0mwl96997` | done |
| `verify.pack.run hygiene-weekly` | `CAP-20260228-034701__verify.pack.run__Rwzfa6953` | done |

## Phase 2 Required Verify Block

| step | command | run_key | status |
|---:|---|---|---|
| 1 | `gate.topology.validate` | `CAP-20260228-034802__gate.topology.validate__Rkvv118341` | done |
| 2 | `verify.route.recommend` | `CAP-20260228-034803__verify.route.recommend__R7bn418599` | done |
| 3 | `verify.pack.run core` | `CAP-20260228-034804__verify.pack.run__Rojwj18857` | done |
| 4 | `verify.pack.run secrets` | `CAP-20260228-034805__verify.pack.run__R6yhh19618` | done |
| 5 | `verify.pack.run workbench` | `CAP-20260228-034822__verify.pack.run__Rmltz26376` | failed |
| 6 | `verify.pack.run hygiene-weekly` | `CAP-20260228-034922__verify.pack.run__Rw57u45325` | failed |
| 7 | `verify.pack.run communications` | `CAP-20260228-035034__verify.pack.run__Rxadb57536` | done |
| 8 | `verify.pack.run mint` | `CAP-20260228-035049__verify.pack.run__Rsjxx59660` | done |
| 9 | `verify.run -- fast` | `CAP-20260228-035133__verify.run__R0qzp64028` | done |
| 10 | `verify.run -- domain communications` | `CAP-20260228-035134__verify.run__Rb8ev64550` | done |
| 11 | `verify.gate_quality.scorecard` | `CAP-20260228-035157__verify.gate_quality.scorecard__Rgmd266729` | done |
| 12 | `verify.freshness.reconcile` | `CAP-20260228-035158__verify.freshness.reconcile__Rgreb66981` | done |
| 13 | `loops.status` (post) | `CAP-20260228-035337__loops.status__Rgt7478968` | done |
| 14 | `gaps.status` (post) | `CAP-20260228-035338__gaps.status__R7ask79338` | done |

## Phase 2 Recovery Re-runs (failed steps only)

| command | run_key | status |
|---|---|---|
| `docs.projection.sync` | `CAP-20260228-035410__docs.projection.sync__Rpd6s85279` | done |
| `docs.projection.verify` | `CAP-20260228-035431__docs.projection.verify__Rsgbh86461` | done |
| `verify.pack.run workbench` (rerun) | `CAP-20260228-035438__verify.pack.run__Rv85c87827` | done |
| `verify.pack.run hygiene-weekly` (rerun) | `CAP-20260228-035439__verify.pack.run__Ru1p187847` | done |
