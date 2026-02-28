# W62-B Gate Portfolio Recommendations (Report-Only)

Generated: 2026-02-28T04:21:53Z
Input scorecard: `/Users/ronnyworks/code/agentic-spine/docs/planning/W62B_GATE_QUALITY_SCORECARD.json`

## Rules Evaluated

- Demotion recommendation: `fail_rate > 50%` and `real_drift_evidence_count == 0` and `exposure_count >= 2`.
- Retirement review recommendation: `pass_rate == 100%` for long horizon (`exposure_count >= 6`).
- Enforcement mode: **report-only**. This capability does **not** mutate `ops/bindings/gate.registry.yaml`.

## Advisory Demotion Candidates (Report-Only)

| gate_id | gate_name | current_class | exposure_count | fail_count | fail_rate | real_drift_evidence_count | candidate_action | rationale |
|---|---|---|---:|---:|---:|---:|---|---|
| none | n/a | n/a | 0 | 0 | 0.00% | 0 | none | no gates met demotion rule in this horizon |

## Retirement Review Candidates (Report-Only)

| gate_id | gate_name | current_class | exposure_count | pass_rate | candidate_action | rationale |
|---|---|---|---:|---:|---|---|
| D121 | fabric-boundary-lock | freshness | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D124 | entry-surface-parity-lock | freshness | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D126 | workbench-implementation-path-lock | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D127 | domain-assignment-drift-lock | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D148 | mcp-agent-runtime-binding-lock | freshness | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D150 | code-root-hygiene-lock | freshness | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D153 | project-attach-parity | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D163 | workbench-ssh-attach-parity-lock | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D164 | workbench-ssh-runtime-normalization-lock | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D165 | workbench-secrets-onboarding-lock | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D166 | workbench-deploy-method-lock | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D167 | workbench-operator-surface-lock | freshness | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D3 | entrypoint-smoke | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |
| D63 | capabilities-metadata-lock | invariant | 9 | 100.00% | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) |

## Summary

- demotion_candidates: **0**
- retirement_review_candidates: **14**
- registry_mutation: **none (report-only)**
