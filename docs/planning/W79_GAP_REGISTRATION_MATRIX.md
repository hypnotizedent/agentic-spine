# W79 Gap Registration Matrix

Wave: `W79_TRUTH_FIRST_RELIABILITY_HARDENING_20260228`
Source report: `mailroom/outbox/reports/W77_FORENSIC_AUDIT_REPORT.md`

## Summary

- total_findings: 54
- true_unresolved_linked_to_gap: 45
- noop_fixed_with_evidence: 8
- stale_false_with_evidence: 1
- unclassified: 0
- registration_acceptance: PASS

## Finding Registry

| finding_id | repo | severity | status | disposition | gap_id | parent_loop | evidence |
|---|---|---|---|---|---|---|---|
| MM-C1 | mint-modules | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1179 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | agents/mcp-server src+build include fixed tailscale IPs |
| MM-C2 | mint-modules | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1180 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | 100.98.70.70 present in quote-page config and deploy compose |
| MM-H1 | mint-modules | high | NOOP_FIXED | noop_fixed | - | - | 10/10 deployed module contracts now include status |
| MM-H2 | mint-modules | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1181 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | route/status_code vs path/status schemas coexist across modules |
| MM-H3 | mint-modules | high | NOOP_FIXED | noop_fixed | - | - | deploy/docker-compose.prod.yml no longer contains ${TAG:-latest} |
| MM-L1 | mint-modules | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1185 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | mixed MINT.MOD.* and bare module_id conventions |
| MM-L2 | mint-modules | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1186 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | .spine-project.yaml references 100.90.167.39:2222 |
| MM-L3 | mint-modules | low | TRUE_UNRESOLVED | linked_gap | GAP-OP-1187 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | docs/PLANNING/INDEX.md lists minimal entries vs 70+ docs |
| MM-M1 | mint-modules | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1182 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | scaffolded modules include runnable source paths |
| MM-M2 | mint-modules | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1183 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | compose healthcheck cadence not normalized across modules |
| MM-M3 | mint-modules | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1184 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | payment module contains TODO replace with postgres adapter |
| S-C1 | agentic-spine | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1150 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | freshness coverage audit (70 active / 18 mapped / 53 unmapped) |
| S-C2 | agentic-spine | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1151 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | no verify.run scheduler references in launchd/runtime contracts |
| S-C3 | agentic-spine | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1152 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | rg hardcoded IPs in wave.sh/services.health/proxy-session/pr.sh |
| S-C4 | agentic-spine | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1153 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | gate.registry D21 has null ring/gate_class/category |
| S-C5 | agentic-spine | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1154 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | agents.registry missing name+runner_capability on 12/12 agents |
| S-H1 | agentic-spine | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1155 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | engine/zai.sh, engine/claude.sh, engine/openai.sh, engine/local_echo.sh missing |
| S-H2 | agentic-spine | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1156 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | README last_verified=2026-02-11 |
| S-H3 | agentic-spine | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1157 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | gaps.status open=96 and many without regression_lock_id |
| S-H4 | agentic-spine | high | STALE_FALSE | stale_false | - | - | current failure history query shows 0 release-scope failures today |
| S-H5 | agentic-spine | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1158 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | proxy-session.sh + pr.sh still include hardcoded defaults |
| S-L1 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | projection surfaces align with gate authority counts |
| S-L2 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | authority map checks currently passing |
| S-L3 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | contract coverage present and routable |
| S-L4 | agentic-spine | low | NOOP_FIXED | noop_fixed | - | - | planning receipts/matrices present on branch |
| S-M1 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1159 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | filesystem sweep shows .tmp/n8n-fix and .tmp/n8n-restore |
| S-M2 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1160 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | docs/brain/_imported/.../verify.md stale age |
| S-M3 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1161 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | operational.gaps breakdown shows missing-entry heavy skew |
| S-M4 | agentic-spine | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1162 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | nightly contract lacks active scheduler execution path |
| WB-C1 | workbench | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1163 | LOOP-W79-T0-SECURITY-EMERGENCY-20260228 | non-empty sensitive token vars detected in tracked .env files |
| WB-C2 | workbench | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1164 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | runtime/streamdeck/config.json contains 100.67.120.1 |
| WB-C3 | workbench | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1165 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | build/index.js includes 100.76.153.100 + fallback URL |
| WB-C4 | workbench | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1166 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | build/index.js references FIREFLY_ACCESS_TOKEN |
| WB-C5 | workbench | critical | NOOP_FIXED | noop_fixed | - | - | ha-sync-agent now present/allowed and no active contract violation reproduced |
| WB-C6 | workbench | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1167 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | media-stack.json contains 192.168.1.209/210 |
| WB-C7 | workbench | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1168 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | simplefin-daily-sync.sh hardcodes /Users/ronnyworks/code/agentic-spine |
| WB-H1 | workbench | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1169 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | legacy-aliases.sh references mintprints-api.ronny.works |
| WB-H2 | workbench | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1170 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | monitoring_inventory includes infra-core:8080 and 100.92.91.128:8080 |
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
| XR-C2 | cross-repo | critical | TRUE_UNRESOLVED | linked_gap | GAP-OP-1189 | LOOP-W79-T1-CRITICAL-STRUCTURAL-20260228 | PAT vs ACCESS_TOKEN mismatch persists across mint/workbench examples and code |
| XR-H1 | cross-repo | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1190 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | no tailscale_ip_registry binding file present in spine |
| XR-H2 | cross-repo | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1191 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | no launchd templates for finance-stack-backup/simplefin-daily-sync |
| XR-H3 | cross-repo | high | TRUE_UNRESOLVED | linked_gap | GAP-OP-1192 | LOOP-W79-T2-HIGH-STRUCTURAL-20260228 | no explicit gates tie mint/workbench satellite runtime state into spine verify rings |
| XR-M1 | cross-repo | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1193 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | mint-modules MCP integration not comprehensively surfaced in spine docs/contracts |
| XR-M2 | cross-repo | medium | TRUE_UNRESOLVED | linked_gap | GAP-OP-1194 | LOOP-W79-T3-MEDIUM-LOW-COSMETIC-20260228 | DNS parity gates rely on manual invocation without autonomous probing cadence |
