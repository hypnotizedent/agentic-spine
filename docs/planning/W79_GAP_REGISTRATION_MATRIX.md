# W79 Gap Registration Matrix

Wave: `W79_TRUTH_FIRST_RELIABILITY_HARDENING_20260228`
Source report: `mailroom/outbox/reports/W77_FORENSIC_AUDIT_REPORT.md`

## Summary

- total_findings: 54
- true_unresolved_linked_to_gap: 25
- fixed_in_program_waves: 17
- blocked_with_evidence: 2
- noop_fixed_with_evidence: 9
- stale_false_with_evidence: 1
- unclassified: 0
- registration_acceptance: PASS

## Finding Registry

| finding_id | repo | severity | status | disposition | gap_id | parent_loop | evidence |
|---|---|---|---|---|---|---|---|
| MM-C1 | mint-modules | critical | FIXED | linked_gap | GAP-OP-1179 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | MCP server hardcoded IP defaults removed; verify.pack.run mint PASS |
| MM-C2 | mint-modules | critical | FIXED | linked_gap | GAP-OP-1180 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Quote webhook defaults normalized to service endpoint; verify.pack.run mint PASS |
| MM-H1 | mint-modules | high | NOOP_FIXED | noop_fixed | - | - | 10/10 deployed module contracts now include status |
| MM-H2 | mint-modules | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1181 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | route/status_code vs path/status schemas coexist across modules |
| MM-H3 | mint-modules | high | NOOP_FIXED | noop_fixed | - | - | deploy/docker-compose.prod.yml no longer contains ${TAG:-latest} |
| MM-L1 | mint-modules | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1185 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | mixed MINT.MOD.* and bare module_id conventions |
| MM-L2 | mint-modules | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1186 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | .spine-project.yaml references 100.90.167.39:2222 |
| MM-L3 | mint-modules | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1187 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | docs/PLANNING/INDEX.md lists minimal entries vs 70+ docs |
| MM-M1 | mint-modules | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1182 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | scaffolded modules include runnable source paths |
| MM-M2 | mint-modules | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1183 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | compose healthcheck cadence not normalized across modules |
| MM-M3 | mint-modules | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1184 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | payment module contains TODO replace with postgres adapter |
| S-C1 | agentic-spine | critical | FIXED | linked_gap | GAP-OP-1150 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Freshness mappings expanded to 70/70 coverage; hygiene-weekly + reconcile PASS |
| S-C2 | agentic-spine | critical | BLOCKED | linked_gap | GAP-OP-1151 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Runtime launchagent install/load required; deferred until RELEASE_RUNTIME_CHANGE_WINDOW |
| S-C3 | agentic-spine | critical | FIXED | linked_gap | GAP-OP-1152 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Hardcoded command-surface IP defaults removed; verify block PASS |
| S-C4 | agentic-spine | critical | FIXED | linked_gap | GAP-OP-1153 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | D21 metadata repaired (ring set); gate topology PASS |
| S-C5 | agentic-spine | critical | FIXED | linked_gap | GAP-OP-1154 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Active agent metadata completed (name + runner_capability) |
| S-H1 | agentic-spine | high | FIXED | linked_gap | GAP-OP-1155 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | README engine provider table corrected to canonical `ops/engine/*.sh` paths |
| S-H2 | agentic-spine | high | FIXED | linked_gap | GAP-OP-1156 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | README `last_verified` refreshed to `2026-02-28` |
| S-H3 | agentic-spine | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1157 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | gaps.status open=96 and many without regression_lock_id |
| S-H4 | agentic-spine | high | STALE_FALSE | stale_false | - | - | current failure history query shows 0 release-scope failures today |
| S-H5 | agentic-spine | high | FIXED | linked_gap | GAP-OP-1158 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | hardcoded proxy defaults removed from governed vaultwarden/gitea command paths |
| S-L1 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | projection surfaces align with gate authority counts |
| S-L2 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | authority map checks currently passing |
| S-L3 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | contract coverage present and routable |
| S-L4 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | planning receipts/matrices present on branch |
| S-M1 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1159 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | filesystem sweep shows .tmp/n8n-fix and .tmp/n8n-restore |
| S-M2 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1160 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | docs/brain/_imported/.../verify.md stale age |
| S-M3 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1161 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | operational.gaps breakdown shows missing-entry heavy skew |
| S-M4 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1162 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | nightly contract lacks active scheduler execution path |
| WB-C1 | workbench | critical | BLOCKED | linked_gap | GAP-OP-1163 | LOOP-W79-T0-SECURITY-EMERGENCY-20260228 | Operator credential rotation pending (GAP-OP-1195/1196/1197) |
| WB-C2 | workbench | critical | FIXED | linked_gap | GAP-OP-1164 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Streamdeck HA URL moved off dead IP |
| WB-C3 | workbench | critical | FIXED | linked_gap | GAP-OP-1165 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Finance stack defaults normalized to canonical host/service endpoints |
| WB-C4 | workbench | critical | FIXED | linked_gap | GAP-OP-1166 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Active FIREFLY key alias normalized to FIREFLY_PAT |
| WB-C5 | workbench | critical | NOOP_FIXED | noop_fixed | - | - | ha-sync-agent now present/allowed and no active contract violation reproduced |
| WB-C6 | workbench | critical | FIXED | linked_gap | GAP-OP-1167 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Media MCP URLs moved to Infisical placeholders |
| WB-C7 | workbench | critical | FIXED | linked_gap | GAP-OP-1168 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | SimpleFIN script now uses portable HOME-based SPINE_ROOT |
| WB-H1 | workbench | high | FIXED | linked_gap | GAP-OP-1169 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | legacy alias api-health moved to canonical api.mintprints.co endpoint |
| WB-H2 | workbench | high | FIXED | linked_gap | GAP-OP-1170 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | infisical monitoring endpoint canonicalized to infra-core hostname source |
| WB-H3 | workbench | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1171 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | 7 skeleton agent directories lack runnable implementation |
| WB-H4 | workbench | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1172 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | 4 agent tool dirs have .env.example without .env |
| WB-H5 | workbench | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1173 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | 13 scripts contain /Users/ronnyworks |
| WB-L1 | workbench | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1177 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | infra/agents/runtime naming conventions mixed |
| WB-L2 | workbench | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1178 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | skeleton readmes present with minimal implementation detail |
| WB-L3 | workbench | low | NOOP_FIXED | noop_fixed | - | - | receipts structure remains contract-compliant |
| WB-M1 | workbench | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1174 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | mixed pinned and latest image policies across compose surfaces |
| WB-M2 | workbench | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1175 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | DEFERRED.md expiries exist without automated enforcement |
| WB-M3 | workbench | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1176 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | placeholder conventions vary (CHANGEME/empty/commented) |
| XR-C1 | cross-repo | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1188 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | cross-repo scan finds >70k files containing /Users/ronnyworks |
| XR-C2 | cross-repo | critical | FIXED | linked_gap | GAP-OP-1189 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | Final non-legacy FIREFLY alias outlier normalized; active workbench+mint surfaces canonicalized |
| XR-H1 | cross-repo | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1190 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | no tailscale_ip_registry binding file present in spine |
| XR-H2 | cross-repo | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1191 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | no launchd templates for finance-stack-backup/simplefin-daily-sync |
| XR-H3 | cross-repo | high | NOOP_FIXED | noop_fixed | GAP-OP-1192 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | D294+D295 satellite parity gates already present and routed in topology/profiles |
| XR-M1 | cross-repo | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1193 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | mint-modules MCP integration not comprehensively surfaced in spine docs/contracts |
| XR-M2 | cross-repo | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1194 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | DNS parity gates rely on manual invocation without autonomous probing cadence |
