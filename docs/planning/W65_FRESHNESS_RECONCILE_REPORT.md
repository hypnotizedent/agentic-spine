# W65 Freshness Reconcile Report

Generated: 2026-02-28T10:26:35Z
Source contract: `/Users/ronnyworks/code/agentic-spine/ops/bindings/freshness.reconcile.contract.yaml`
Source registry: `/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.registry.yaml`

## Summary

- freshness_gates_total: **68**
- pass_count: **68**
- refreshed_count: **0**
- rerun_count: **0**
- unresolved_count: **0**

## Unresolved Reason Counts

| reason | count |
|---|---:|
| none | 0 |

## Gate Reconciliation Detail

| gate_id | gate_name | initial_status | refresh_capability | refresh_status | final_status | unresolved_reason |
|---|---|---|---|---|---|---|
| D5 | no-legacy-coupling | pass | n/a | not_applicable | pass | n/a |
| D11 | home-surface | pass | n/a | not_applicable | pass | n/a |
| D17 | root-allowlist | pass | n/a | not_applicable | pass | n/a |
| D26 | agent-read-surface | pass | n/a | not_applicable | pass | n/a |
| D32 | codex-instruction-source-lock | pass | n/a | not_applicable | pass | n/a |
| D48 | codex-worktree-hygiene | pass | n/a | not_applicable | pass | n/a |
| D49 | agent-discovery-lock | pass | n/a | not_applicable | pass | n/a |
| D56 | agent-entry-surface-lock | pass | n/a | not_applicable | pass | n/a |
| D58 | ssot-freshness-lock | pass | n/a | not_applicable | pass | n/a |
| D59 | cross-registry-completeness-lock | pass | n/a | not_applicable | pass | n/a |
| D61 | session-loop-traceability-lock | pass | n/a | not_applicable | pass | n/a |
| D65 | agent-briefing-sync-lock | pass | n/a | not_applicable | pass | n/a |
| D66 | mcp-server-parity-gate | pass | n/a | not_applicable | pass | n/a |
| D93 | tenant-storage-boundary-lock | pass | n/a | not_applicable | pass | n/a |
| D99 | ha-token-freshness | pass | n/a | not_applicable | pass | n/a |
| D102 | ha-device-map-freshness | pass | n/a | not_applicable | pass | n/a |
| D104 | home-dhcp-audit-freshness | pass | n/a | not_applicable | pass | n/a |
| D112 | secrets-access-pattern-lock | pass | n/a | not_applicable | pass | n/a |
| D115 | ha-ssot-baseline-freshness | pass | n/a | not_applicable | pass | n/a |
| D118 | z2m-device-health | pass | n/a | not_applicable | pass | n/a |
| D121 | fabric-boundary-lock | pass | n/a | not_applicable | pass | n/a |
| D124 | entry-surface-parity-lock | pass | n/a | not_applicable | pass | n/a |
| D131 | catalog-freshness-lock | pass | n/a | not_applicable | pass | n/a |
| D139 | nas-baseline-coverage | pass | n/a | not_applicable | pass | n/a |
| D142 | receipt-index-freshness | pass | n/a | not_applicable | pass | n/a |
| D147 | communications-canonical-routing-lock | pass | n/a | not_applicable | pass | n/a |
| D148 | mcp-agent-runtime-binding-lock | pass | n/a | not_applicable | pass | n/a |
| D150 | code-root-hygiene-lock | pass | n/a | not_applicable | pass | n/a |
| D151 | communications-boundary-lock | pass | n/a | not_applicable | pass | n/a |
| D156 | governance-freshness-and-receipts-policy-lock | pass | n/a | not_applicable | pass | n/a |
| D157 | proposals-lifecycle-linkage-lock | pass | n/a | not_applicable | pass | n/a |
| D159 | weekly-execution-telemetry-lock | pass | n/a | not_applicable | pass | n/a |
| D162 | operator-smoothness-lock | pass | n/a | not_applicable | pass | n/a |
| D167 | workbench-operator-surface-lock | pass | n/a | not_applicable | pass | n/a |
| D174 | service-onboarding-parity-lock | pass | n/a | not_applicable | pass | n/a |
| D176 | platform-extension-transaction-lock | pass | n/a | not_applicable | pass | n/a |
| D178 | platform-extension-lifecycle-lock | pass | n/a | not_applicable | pass | n/a |
| D179 | platform-extension-artifact-completeness-lock | pass | n/a | not_applicable | pass | n/a |
| D185 | inventory-home-union-lock | pass | n/a | not_applicable | pass | n/a |
| D191 | media-content-ledger-parity-lock | pass | n/a | not_applicable | pass | n/a |
| D192 | media-content-snapshot-freshness-lock | pass | n/a | not_applicable | pass | n/a |
| D193 | ha-inventory-snapshot-completeness-lock | pass | n/a | not_applicable | pass | n/a |
| D194 | network-inventory-snapshot-parity-lock | pass | n/a | not_applicable | pass | n/a |
| D201 | domain-registrar-parity-lock | pass | n/a | not_applicable | pass | n/a |
| D202 | domain-transfer-readiness-lock | pass | n/a | not_applicable | pass | n/a |
| D205 | calendar-home-union-ingest-lock | pass | n/a | not_applicable | pass | n/a |
| D208 | calendar-ha-snapshot-freshness-lock | pass | n/a | not_applicable | pass | n/a |
| D213 | secrets-registered-route-lock | pass | n/a | not_applicable | pass | n/a |
| D215 | mintprints-tunnel-ingress-lock | pass | n/a | not_applicable | pass | n/a |
| D220 | media-recyclarr-language-enforcement-lock | pass | n/a | not_applicable | pass | n/a |
| D225 | mint-live-before-auth-lock | pass | n/a | not_applicable | pass | n/a |
| D232 | media-sqlite-storage-lock | pass | n/a | not_applicable | pass | n/a |
| D233 | communications-mail-archiver-nonboot-storage-lock | pass | n/a | not_applicable | pass | n/a |
| D234 | infra-boot-drive-usage-lock | pass | n/a | not_applicable | pass | n/a |
| D235 | infra-storage-placement-lock | pass | n/a | not_applicable | pass | n/a |
| D237 | docker-root-budget-lock | pass | n/a | not_applicable | pass | n/a |
| D239 | storage-audit-snapshot-lock | pass | n/a | not_applicable | pass | n/a |
| D252 | container-oom-exit-lock | pass | n/a | not_applicable | pass | n/a |
| D253 | service-health-state-aware-lock | pass | n/a | not_applicable | pass | n/a |
| D254 | image-age-budget-lock | pass | n/a | not_applicable | pass | n/a |
| D255 | md1400-capacity-monitor-lock | pass | n/a | not_applicable | pass | n/a |
| D256 | credential-spof-lock | pass | n/a | not_applicable | pass | n/a |
| D257 | media-capacity-guard-lock | pass | n/a | not_applicable | pass | n/a |
| D277 | runtime-freshness-reconcile-automation-lock | pass | n/a | not_applicable | pass | n/a |
| D281 | ssh-target-lifecycle-lock | pass | n/a | not_applicable | pass | n/a |
| D283 | domain-taxonomy-bridge-parity-lock | pass | n/a | not_applicable | pass | n/a |
| D286 | critical-asset-utilization-freshness-lock | pass | n/a | not_applicable | pass | n/a |
| D287 | verify-failure-snapshot-fatigue-lock | pass | n/a | not_applicable | pass | n/a |
