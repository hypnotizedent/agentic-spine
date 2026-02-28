# W76 Run Key Ledger

wave_id: W76_HOLISTIC_CANONICAL_CLOSURE_20260228
branch: codex/w76-holistic-canonical-closure-20260228

| phase | command | run_key | result |
|---|---|---|---|
| phase0 | `./bin/ops cap run session.start` | `CAP-20260228-070044__session.start__Rbht392141` | PASS |
| phase0 | `./bin/ops cap run loops.status` | `CAP-20260228-070102__loops.status__Rjb2b98861` | PASS |
| phase0 | `./bin/ops cap run gaps.status` | `CAP-20260228-070103__gaps.status__Rfsf999290` | PASS |
| phase0 | `./bin/ops cap run gate.topology.validate` | `CAP-20260228-070105__gate.topology.validate__Ruj832538` | PASS |
| phase0 | `./bin/ops cap run verify.route.recommend` | `CAP-20260228-070105__verify.route.recommend__Rjehk2804` | PASS |
| phase0 | `./bin/ops cap run loops.create --name "W76 Holistic Canonical Closure" --objective "Holistic canonical closure across spine/workbench/mint"` | `CAP-20260228-070106__loops.create__Ruwhj3067` | PASS |
| phase1 | `./bin/ops cap run rag.reindex.smoke` | `CAP-20260228-070838__rag.reindex.smoke__Rb0j314992` | PASS (dry-run) |
| phase1 | `./bin/ops cap run rag.reindex.smoke --execute` | `CAP-20260228-070901__rag.reindex.smoke__Ra0x320692` | FAIL (arg misuse) |
| phase2 | `./bin/ops cap run docs.projection.sync` | `CAP-20260228-071707__docs.projection.sync__R334q38046` | PASS |
| phase5 | `./bin/ops cap run gate.topology.validate` | `CAP-20260228-072214__gate.topology.validate__Roepg52511` | PASS |
| phase5 | `./bin/ops cap run verify.route.recommend` | `CAP-20260228-072214__verify.route.recommend__R3f8852762` | PASS |
| phase5 | `./bin/ops cap run verify.pack.run core` | `CAP-20260228-072215__verify.pack.run__R3mez53009` | PASS |
| phase5 | `./bin/ops cap run verify.pack.run secrets` | `CAP-20260228-072216__verify.pack.run__Ratyf53943` | PASS |
| phase5 | `./bin/ops cap run verify.pack.run workbench` | `CAP-20260228-072233__verify.pack.run__R47q160176` | PASS |
| phase5 | `./bin/ops cap run verify.pack.run hygiene-weekly` | `CAP-20260228-072331__verify.pack.run__Rx6ml80489` | PASS |
| phase5 | `./bin/ops cap run verify.pack.run communications` | `CAP-20260228-072354__verify.pack.run__Rx7n691473` | PASS |
| phase5 | `./bin/ops cap run verify.pack.run mint` | `CAP-20260228-072401__verify.pack.run__Rxfxf93432` | PASS |
| phase5 | `./bin/ops cap run verify.run -- fast` | `CAP-20260228-072435__verify.run__R5sa92522` | PASS |
| phase5 | `./bin/ops cap run verify.run -- domain communications` | `CAP-20260228-072437__verify.run__R9olj3487` | PASS |
| phase5 | `./bin/ops cap run loops.status` | `CAP-20260228-072444__loops.status__R0ch65988` | PASS |
| phase5 | `./bin/ops cap run gaps.status` | `CAP-20260228-072444__gaps.status__R48ao6452` | PASS |
| phase5 | `./bin/ops cap run docs.projection.verify` | `CAP-20260228-072459__docs.projection.verify__Rt0de11283` | PASS |
| w76b | `./bin/ops cap run session.start` | `CAP-20260228-074005__session.start__Rhvl059096` | PASS |
| w76b | `./bin/ops cap run verify.pack.run core` | `CAP-20260228-074455__verify.pack.run__Rotzg76960` | PASS |
| w76b | `./bin/ops cap run verify.pack.run hygiene-weekly` | `CAP-20260228-074458__verify.pack.run__Retw477701` | PASS |
| w76b | `./bin/ops cap run verify.run -- fast` | `CAP-20260228-074526__verify.run__Rb8hi89079` | PASS |
| w76b | `./bin/ops cap run loops.status` | `CAP-20260228-074530__loops.status__Ricn689557` | PASS |
| w76b | `./bin/ops cap run gaps.status` | `CAP-20260228-074532__gaps.status__Re7ug89808` | PASS |

## Non-run-key Gate Evidence

- `bash surfaces/verify/d83-proposal-queue-health-lock.sh` -> PASS
- W76B baseline `bash surfaces/verify/d111-rag-embedding-smoke-preflight.sh` -> FAIL (`remote_execution_failed`)
- W76B recovery `./ops/plugins/rag/bin/rag-reindex-smoke --batch-size 1 --execute` -> PASS (`uploaded=1, failed=0`, evidence: `mailroom/state/rag-sync/smoke-evidence.json`)
- W76B post-check `bash surfaces/verify/d111-rag-embedding-smoke-preflight.sh` -> PASS
- `bash surfaces/verify/d284-gap-reference-integrity-lock.sh` -> PASS
