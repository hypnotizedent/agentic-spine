# W78 Reliability Hardening Report

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228
branch: codex/w78-truth-first-reliability-hardening-20260228

## Scope Applied (TRUE_UNRESOLVED Claims Only)

| claim_id | hardening action | files | evidence |
|---|---|---|---|
| C4 | Removed invariant-lane fail-open precondition bypasses from HA gates and added D293 invariant lock | `surfaces/verify/d113-coordinator-health-probe.sh`, `surfaces/verify/d114-ha-automation-stability.sh`, `surfaces/verify/d118-z2m-device-health.sh`, `surfaces/verify/d120-ha-area-parity.sh`, `surfaces/verify/d293-ha-invariant-precondition-fail-open-lock.sh`, `ops/bindings/gate.registry.yaml`, `ops/bindings/gate.execution.topology.yaml`, `ops/bindings/gate.domain.profiles.yaml` | `CAP-20260228-082937__verify.pack.run__R9t3o74492` (D293 PASS) |
| C5 | Expanded freshness mappings for critical and high-stale operational gates; filed backlog governance gap for remaining unmapped set | `ops/bindings/freshness.reconcile.contract.yaml`, `ops/bindings/operational.gaps.yaml` (GAP-OP-1149) | `CAP-20260228-083041__verify.freshness.reconcile__Rlshg93863` (`unresolved_count=1`) |
| C6 | Added missing launchd contract labels and missing governed template; produced report-only runtime enablement plan | `ops/bindings/launchd.runtime.contract.yaml`, `ops/runtime/launchd/com.ronny.ha-baseline-refresh.plist` | `CAP-20260228-082821__verify.pack.run__Redpt40680` (D148 still failing on install/load parity without runtime token) |

## Additional Governance Debt Closures

| item | action | files |
|---|---|---|
| D168/D172 skip rationale | Added explicit skip rationale comments in gate authority | `ops/bindings/gate.registry.yaml` |
| GAP-OP-328 quality | Expanded description to substantive governance form | `ops/bindings/operational.gaps.yaml` |
| worker contract parser safety | Normalized worker contract to parser-safe single-doc form | `ops/bindings/mailroom.task.worker.contract.yaml` |

## Result

- C4: resolved in code and gate coverage.
- C5: partially resolved; critical coverage complete, staged backlog captured as governed gap.
- C6: partially resolved; contract/template parity done, runtime install/load pending tokened runtime-enable path.
