# W76 Acceptance Matrix

wave_id: W76_HOLISTIC_CANONICAL_CLOSURE_20260228
branch: codex/w76-holistic-canonical-closure-20260228
status: final

## Baseline vs Final Counters

| metric | baseline | final | delta | result |
|---|---:|---:|---:|---|
| open_loops | 19 | 20 | +1 (control loop opened) | PASS |
| open_gaps | 92 | 95 | +3 (phantom IDs 1024-1026 canonically registered as open) | PASS |
| orphaned_open_gaps | 0 | 0 | 0 | PASS |

## Binary Acceptance

| id | requirement | result | evidence |
|---|---|---|---|
| A1 | D160 collision resolved and no orphan gate script | PASS | D292 script rename + D160 retained in gate registry/profile topology |
| A2 | D292 registered and metadata counts synchronized everywhere | PASS | `gate_count_total=290`, `max_gate_id=D292`, topology/profiles include D292 |
| A3 | GAP-OP-1024..1028 no longer phantom | PASS | Backfilled in `ops/bindings/operational.gaps.yaml`; D284 PASS |
| A4 | D83 passes | PASS | `bash surfaces/verify/d83-proposal-queue-health-lock.sh` |
| A5 | D111 passes | PASS | baseline: `bash surfaces/verify/d111-rag-embedding-smoke-preflight.sh` -> FAIL (`remote_execution_failed`); recovered via `./ops/plugins/rag/bin/rag-reindex-smoke --batch-size 1 --execute`; post-check: `bash surfaces/verify/d111-rag-embedding-smoke-preflight.sh` -> PASS |
| A6 | D113/D114/D118/D120 no silent-pass behavior on precondition failure | PASS | scripts now enforce `HA_GATE_MODE=enforce` by default |
| A7 | digital-proofs included in CI test/build/push | PASS | `mint-modules/.gitea/workflows/ci.yaml` job + needs + build/push module list |
| A8 | 5 target Dockerfiles include shared-auth copy path | PASS | artwork/order-intake/quote-page/finance-adapter/shopify-module Dockerfiles |
| A9 | SERVICE_REGISTRY + vm.lifecycle + STACK_REGISTRY mint parity updated | PASS | updated registry and VM 213 service inventory |
| A10 | 7 guard scripts wired into CI | PASS | guards job includes archive/mint/repo guard scripts |
| A11 | deployed module contracts have explicit lifecycle status | PASS | deployed module `status: deployed`; scaffolded kept scaffolded |
| A12 | planning index expanded from stub to broad coverage | PASS | mint planning index now 76/76 coverage excluding index |
| A13 | legacy/cosmetic closure items completed | PASS | tombstone, stale worktree dir removed, README/test/naming/cloudflare format updates |
| A14 | pre-existing ndjson telemetry file preserved and unstaged | PASS | `ops/plugins/verify/state/verify-failure-class-history.ndjson` unchanged and excluded from staging |
| A15 | required verify block passes | PASS | all required phase5 run keys PASS in `W76_RUN_KEY_LEDGER.md` |
| A16 | orphaned open gaps remain 0 | PASS | `CAP-20260228-072444__gaps.status__R48ao6452` |

## Summary

- acceptance_score: 16/16 PASS
- decision: MERGE_READY
