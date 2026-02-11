---
status: closed
owner: "@ronny"
last_verified: 2026-02-11
closed_at: 2026-02-11
scope: loop-scope
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
severity: high
---

# Loop Scope: LOOP-FINANCE-LEGACY-EXTRACTION-20260211

## Goal

Extract finance-stack operational knowledge from legacy source into spine-native docs using Move A (doc-only snapshots). Finance is classified as a **Pillar** per EXTRACTION_PROTOCOL.md — 7+ containers, business domain, separate lifecycle.

## Parent References

- **Audit:** `docs/governance/FINANCE_LEGACY_EXTRACTION_MATRIX.md` (applied via CP-20260211-102929)
- **Gap:** GAP-OP-093 (finance stack operational coverage)
- **Legacy source:** `https://github.com/hypnotizedent/ronny-ops.git` @ `1ea9dfa9`
- **Pattern precedent:** LOOP-MEDIA-LEGACY-EXTRACTION-20260211

## Success Criteria

- 8 extract_now items from the extraction matrix are rewritten as spine-native Move A docs
- No runtime dependency on legacy repo (D30, LEGACY_DEPRECATION.md)
- No deprecated path wording in authoritative positions (D60)
- All docs pass `docs.lint` and `spine.verify`
- Extraction matrix updated with disposition status

## Phases

- **P0:** Register loop + extraction matrix audit — **COMPLETE** (CP-20260211-102929, commits bbe30a3..0bde025)
- **P1:** Extract all 8 extract_now items — **COMPLETE** (CP-20260211-104745, commit c768e63)
  - F-01: `docs/brain/lessons/FINANCE_SIMPLEFIN_PIPELINE.md` (CRITICAL — bank sync)
  - F-02: `docs/brain/lessons/FINANCE_N8N_WORKFLOWS.md` (CRITICAL — webhook sync)
  - F-03: `docs/brain/lessons/FINANCE_BACKUP_RESTORE.md` (CRITICAL — backup/restore)
  - F-04: `docs/brain/lessons/FINANCE_ACCOUNT_TOPOLOGY.md` (CRITICAL — account registry)
  - F-05: `docs/brain/lessons/FINANCE_STACK_ARCHITECTURE.md` (HIGH — compose topology)
  - F-06: `docs/brain/lessons/FINANCE_DEPLOY_RUNBOOK.md` (HIGH — deployment)
  - F-09: `docs/brain/lessons/FINANCE_RECONCILIATION.md` (HIGH — reconciliation)
  - F-10: `docs/brain/lessons/FINANCE_TROUBLESHOOTING.md` (HIGH — debug)
- **P2:** Binding updates — **COMPLETE** (CP-20260211-105256: health checks, backup enable, secrets namespace)
- **P3:** Pillar structure — **COMPLETE** (CP-20260211-105256: `docs/pillars/finance/{README,ARCHITECTURE,EXTRACTION_STATUS}.md`)
- **P4:** Validate via `spine.verify` + close — **COMPLETE** (RCAP-20260211-105717__spine.verify__Rzi6011258 — PASS)

## Deferred (Future Loops)

- F-08: Receipt scanning workflow (Paperless running; low urgency)
- F-11: Mail-archiver (separate lifecycle)
- F-12: MCP server configs (rebuildable)

## Receipts

- RCAP-20260211-103916__spine.verify__Rgbvk46789 (baseline — PASS after P0)
- RCAP-20260211-105213__proposals.apply__Rsth982892 (P1 applied — 8 spine-native docs)
- RCAP-20260211-105626__proposals.apply__Rfstv2128 (P2+P3 applied — bindings + pillar)
- RCAP-20260211-105717__spine.verify__Rzi6011258 (P4 — PASS, all gates green)
