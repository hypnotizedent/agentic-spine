# W69 Run Key Ledger

wave_id: W69_BRANCH_DRIFT_AND_REGISTRATION_HARDENING_20260228

## Phase 0

| command | run_key | status |
|---|---|---|
| `session.start` | `CAP-20260228-025828__session.start__Rinsw54886` | done |
| `loops.status` (pre) | `CAP-20260228-025848__loops.status__Rl58q61993` | done |
| `gaps.status` (pre) | `CAP-20260228-025848__gaps.status__Rx83661994` | done |
| `loops.create` | `CAP-20260228-025856__loops.create__Rrlvk63456` | done |

## Freshness / Remediation Supporting Runs

| command | run_key | status |
|---|---|---|
| `platform.extension.index.build` | `CAP-20260228-030747__platform.extension.index.build__R65u846615` | done |
| `domain-inventory-refresh -- --once` | `CAP-20260228-030750__domain-inventory-refresh__Rbis447116` | failed |
| `docs.projection.sync` | `CAP-20260228-032209__docs.projection.sync__Rr9sm74424` | done |
| `docs.projection.verify` | `CAP-20260228-032209__docs.projection.verify__Rz9du74425` | failed |
| `gaps.file (GAP-OP-1109)` | `CAP-20260228-032441__gaps.file__Ruv553495` | done |

## Phase 5 Required Verification Block

| command | run_key | status |
|---|---|---|
| `gate.topology.validate` | `CAP-20260228-031554__gate.topology.validate__R940j94340` | done |
| `verify.route.recommend` | `CAP-20260228-031554__verify.route.recommend__Ratpk94602` | done |
| `verify.pack.run core` | `CAP-20260228-031555__verify.pack.run__Rozyq95080` | done |
| `verify.pack.run secrets` | `CAP-20260228-031556__verify.pack.run__Rugi795866` | done |
| `verify.pack.run workbench` | `CAP-20260228-032223__verify.pack.run__R9g9k76278` | done |
| `verify.pack.run hygiene-weekly` | `CAP-20260228-031700__verify.pack.run__Rzofg23378` | failed |
| `verify.pack.run communications` | `CAP-20260228-031722__verify.pack.run__Rvw6n35148` | done |
| `verify.pack.run mint` | `CAP-20260228-031729__verify.pack.run__R8cta37272` | done |
| `verify.run -- fast` | `CAP-20260228-031752__verify.run__Rs5wk41276` | done |
| `verify.run -- domain communications` | `CAP-20260228-031753__verify.run__R5cdo41765` | done |
| `verify.gate_quality.scorecard` | `CAP-20260228-031819__verify.gate_quality.scorecard__Rhwku45417` | done |
| `verify.freshness.reconcile` | `CAP-20260228-031320__verify.freshness.reconcile__Rflkw78340` | done |
| `loops.status` (post) | `CAP-20260228-032618__loops.status__Ry7ev13083` | done |
| `gaps.status` (post) | `CAP-20260228-032618__gaps.status__Rw40m13084` | done |
