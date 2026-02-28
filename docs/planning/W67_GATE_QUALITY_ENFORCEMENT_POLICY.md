# W67 Gate Quality / Budget / Freshness Enforcement Policy

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
status: authoritative-for-wave

## Policy Summary

| control plane | mode | blocking? | source |
|---|---|---|---|
| gate quality scoring (`verify.gate_quality.scorecard`) | telemetry | no | `docs/planning/W62B_GATE_QUALITY_SCORECARD.json` |
| portfolio recommendations (`verify.gate_portfolio.recommendations`) | report-only | no | `docs/planning/W67_GATE_PORTFOLIO_RECOMMENDATIONS.{md,json}` |
| budget add-one-retire-one (`D291`) | enforce | yes (on violations) | `gate.budget.add_one_retire_one.contract.yaml` + D291 gate script |
| freshness reconcile (`verify.freshness.reconcile`) | reconciliation/report | no (command completion required) | `docs/planning/W65_FRESHNESS_RECONCILE_REPORT.{md,json}` |

## Enforcement Rules

1. `D291` fails when `violations > 0` and effective mode is `enforce`.
2. Effective mode resolution order for D291:
   - `SPINE_ENFORCEMENT_MODE` env override (`enforce|report-only`)
   - else contract/policy (`enforce` in W67)
3. Recommendation engine remains non-mutating in W67.
4. Freshness reconcile must emit unresolved reasons by gate id; unresolved items are governance input, not silent pass.

## Governance Guarantees

- No automatic gate registry demotion/retirement in W67.
- Budget enforcement is deterministic and reversible via kill-switch.
- Report-only controls kept report-only include explicit rationale in eligibility matrix.

W67-4 policy intent: **satisfied**.
