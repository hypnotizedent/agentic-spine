# W67 Enforcement Eligibility Matrix

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
phase_gate: P2

| control_id | surface | pre_mode | eligibility | decision | post_mode | rationale | evidence |
|---|---|---|---|---|---|---|---|
| D291 | `surfaces/verify/d291-gate-budget-add-one-retire-one-lock.sh` | report-only | eligible | flipped | enforce | Deterministic policy signal; zero current violations; explicit kill-switch available. | `ops/bindings/gate.enforcement.policy.yaml`, `ops/bindings/gate.budget.add_one_retire_one.contract.yaml` |
| D4 | `ops/bindings/gate.registry.yaml` (inline watcher advisory) | report-only | deferred | no flip | report-only | Workstation-specific watcher signal remains advisory; enforcing would produce false blocks. | `gate.registry.yaml` (`warn_only: true`), `gate.enforcement.policy.yaml` |
| verify.gate_quality.scorecard | `ops/plugins/verify/bin/gate-quality-scorecard` | report-only | deferred | no flip | report-only | Telemetry/report generator, not a blocking invariant gate. | capability contract + W67 run key |
| verify.gate_portfolio.recommendations | `ops/plugins/verify/bin/gate-portfolio-recommendations` | report-only | deferred | no flip | report-only | Explicit policy requirement for report-only recommendation engine in this wave. | W67 run key + recommendations artifacts |
| verify.freshness.reconcile | `ops/plugins/verify/bin/verify-freshness-reconcile` | report-only | deferred | no flip | report-only | Reconciliation can depend on external freshness sources; keep remediation non-blocking while reporting unresolved reasons. | W67 reconcile run key + report |

W67-1 result: **PASS** (matrix complete with flipped vs deferred and explicit rationale).
