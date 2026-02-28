# W78 Truth Matrix

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228
policy: truth-first (no implementation before classification)

| claim_id | claim | status | evidence | action | phase2_outcome |
|---|---|---|---|---|---|
| C1 | digital-proofs absent from CI test/build/push | NOOP_FIXED | `rg -n "digital-proofs" /Users/ronnyworks/code/mint-modules/.gitea/workflows/ci.yaml` (jobs/needs/build/push include digital-proofs) | no implementation | unchanged |
| C2 | phantom GAP-OP-1024..1028 missing from registry | NOOP_FIXED | `rg -n "GAP-OP-1024|...|GAP-OP-1028" ops/bindings/operational.gaps.yaml` -> all 5 present | no implementation | unchanged |
| C3 | D160 collision unresolved | NOOP_FIXED | `rg -n "id: D160|id: D292" ops/bindings/gate.registry.yaml`; both scripts exist (`d160-plugin-pointer-parity`, `d292-communications-queue`) | no implementation | unchanged |
| C4 | D113/D114/D118/D120 silent-pass risk | TRUE_UNRESOLVED | targeted scripts contained report-mode precondition bypass (`HA_GATE_MODE==report` path returns report+exit0) | harden scripts + add invariant fail-open lock gate | RESOLVED: fail-open paths removed, D293 added and passing in hygiene-weekly |
| C5 | 57/69 freshness unmapped | TRUE_UNRESOLVED | freshness coverage audit baseline: `freshness_total=69 mapped=12 unmapped=57` | expand mappings + gap for remaining unmapped | PARTIAL: critical mappings added (D188/D191/D192/D193/D194 + D205/D208/D239), governance gap filed as `GAP-OP-1149` for remaining backlog |
| C6 | launchd.runtime.contract missing 3 refresh labels | TRUE_UNRESOLVED | `rg -n "com.ronny.ha-baseline-refresh|com.ronny.domain-inventory-refresh-daily|com.ronny.extension-index-refresh-daily" ops/bindings/launchd.runtime.contract.yaml` -> no matches | add required labels + runtime enablement plan (token-gated) | PARTIAL: contract labels + missing template added; runtime install/load parity still blocked without `RELEASE_RUNTIME_CHANGE_WINDOW` |
| C7 | SERVICE_REGISTRY / vm.lifecycle / STACK_REGISTRY mint parity drift | NOOP_FIXED | service/vm parity checks show required mint services present (`order-intake`,`finance-adapter`,`pricing`,`suppliers`,`shipping`,`payment`) in SERVICE_REGISTRY + VM 213 lifecycle; stack registry no `/home/docker-host/stacks` stale refs | no implementation | unchanged |
| C8 | D283 taxonomy mismatch | NOOP_FIXED | `bash surfaces/verify/d283-domain-taxonomy-bridge-parity-lock.sh` -> PASS | no implementation | unchanged |

## Summary

- TRUE_UNRESOLVED: 3
- NOOP_FIXED: 5
- STALE_FALSE: 0
- NOT_APPLICABLE: 0

## Implementation Scope for Phase 2

- C4, C5, C6 only
