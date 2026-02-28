# W65 Gate Portfolio Recommendations (Report-Only)

Generated: 2026-02-28T06:35:01Z
Input scorecard: `/Users/ronnyworks/code/agentic-spine/docs/planning/W62B_GATE_QUALITY_SCORECARD.json`

## Rules Evaluated

- Demotion recommendation: `fail_rate > 50%` and `real_drift_evidence_count == 0` and `exposure_count >= 2`.
- Retirement review recommendation: `pass_rate == 100%` for long horizon (`exposure_count >= 6`).
- Enforcement mode: **report-only**. This capability does **not** mutate `ops/bindings/gate.registry.yaml`.

## Recommendations

| gate_id | gate_name | current_class | recommendation_type | reason | confidence | next_action |
|---|---|---|---|---|---|---|
| D121 | fabric-boundary-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D124 | entry-surface-parity-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D126 | workbench-implementation-path-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D127 | domain-assignment-drift-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D147 | communications-canonical-routing-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D148 | mcp-agent-runtime-binding-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D150 | code-root-hygiene-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D151 | communications-boundary-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D153 | project-attach-parity | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D163 | workbench-ssh-attach-parity-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D164 | workbench-ssh-runtime-normalization-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D165 | workbench-secrets-onboarding-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D166 | workbench-deploy-method-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D167 | workbench-operator-surface-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D175 | operator-commitments-union-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D195 | domain-authority-boundary-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D196 | microsoft-provider-write-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D197 | calendar-provider-readonly-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D198 | calendar-home-runtime-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D199 | calendar-home-provider-boundary-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D203 | external-provider-readonly-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D204 | external-provider-secrets-materialization-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D205 | calendar-home-union-ingest-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D206 | calendar-ha-readonly-boundary-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D207 | calendar-ha-contract-materialization-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D208 | calendar-ha-snapshot-freshness-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D209 | communications-tls-health-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D222 | quote-alert-provider-boundary-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D233 | communications-mail-archiver-nonboot-storage-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D252 | container-oom-exit-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D253 | service-health-state-aware-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D256 | credential-spof-lock | freshness | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D258 | ssh-lifecycle-cross-registry-parity-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D259 | onboarding-canonical-registration-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D260 | noninteractive-monitor-access-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D261 | auth-loop-blocked-auth-guard-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D262 | ssh-tailscale-duplicate-truth-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D268 | resend-mcp-transactional-send-authority-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D269 | communications-resend-webhook-schema-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D270 | communications-contacts-governance-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D271 | communications-broadcast-governance-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D272 | n8n-resend-direct-bypass-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D273 | communications-resend-expansion-contract-parity-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D290 | outcome-slo-presence-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | medium | open retirement review with owner and expiry |
| D3 | entrypoint-smoke | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |
| D63 | capabilities-metadata-lock | invariant | retire_review | pass_rate == 100% for long horizon (>= 6 exposures) | high | open retirement review with owner and expiry |

## Summary

- demotion_candidates: **0**
- retirement_review_candidates: **46**
- registry_mutation: **none (report-only)**
