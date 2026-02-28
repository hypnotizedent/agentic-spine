# W65 Gate Budget Report (Report-Only)

Generated: 2026-02-28T06:28:32Z
Contract: `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.budget.add_one_retire_one.contract.yaml`
Registry: `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.registry.yaml`
Recommendations: `/Users/ronnyworks/code/agentic-spine/docs/planning/W65_GATE_PORTFOLIO_RECOMMENDATIONS.json` (recommendations source missing)

## Metrics

- baseline_invariants: **206**
- current_invariants: **206**
- invariants_added: **0**
- invariants_retired: **0**
- delta: **0**
- retirement_or_demotion_plan_count: **0**
- violations: **0**

## Rule

- Violation when `net_new_invariants > 0` and there is no matching retirement/demotion plan coverage.
- Enforcement mode in W65: **report-only** (no blocking, no registry mutation).
