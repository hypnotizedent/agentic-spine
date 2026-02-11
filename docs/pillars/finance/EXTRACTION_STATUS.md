---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-extraction-status
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
---

# Finance Pillar: Extraction Status

## Summary

| Metric | Value |
|--------|-------|
| Classification | PILLAR |
| Loop | LOOP-FINANCE-LEGACY-EXTRACTION-20260211 |
| Gap | GAP-OP-093 |
| Legacy source | `ronny-ops` @ `1ea9dfa9` |
| Total artifacts audited | 150+ |
| Extract now | 8 (all EXTRACTED) |
| Deferred | 3 |
| Rejected | 4 |
| Superseded | 2 |

## Extraction Disposition (Final)

| ID | Artifact | Disposition | Target | Status |
|----|----------|-------------|--------|--------|
| F-01 | SimpleFIN sync pipeline | **EXTRACTED** | `docs/brain/lessons/FINANCE_SIMPLEFIN_PIPELINE.md` | P1 complete (c768e63) |
| F-02 | n8n workflows + category mapping | **EXTRACTED** | `docs/brain/lessons/FINANCE_N8N_WORKFLOWS.md` | P1 complete (c768e63) |
| F-03 | Backup/restore procedures | **EXTRACTED** | `docs/brain/lessons/FINANCE_BACKUP_RESTORE.md` | P1 complete (c768e63) |
| F-04 | Account registry | **EXTRACTED** | `docs/brain/lessons/FINANCE_ACCOUNT_TOPOLOGY.md` | P1 complete (c768e63) |
| F-05 | Docker compose topology | **EXTRACTED** | `docs/brain/lessons/FINANCE_STACK_ARCHITECTURE.md` | P1 complete (c768e63) |
| F-06 | Deployment runbook | **EXTRACTED** | `docs/brain/lessons/FINANCE_DEPLOY_RUNBOOK.md` | P1 complete (c768e63) |
| F-07 | SimpleFIN setup + credentials | **EXTRACTED** | Folded into FINANCE_SIMPLEFIN_PIPELINE.md | P1 complete (c768e63) |
| F-08 | Receipt scanning workflow | **DEFERRED** | Future loop | Paperless running; low urgency |
| F-09 | Reconciliation scripts | **EXTRACTED** | `docs/brain/lessons/FINANCE_RECONCILIATION.md` | P1 complete (c768e63) |
| F-10 | Troubleshooting guide | **EXTRACTED** | `docs/brain/lessons/FINANCE_TROUBLESHOOTING.md` | P1 complete (c768e63) |
| F-11 | Mail-archiver | **DEFERRED** | Future loop | Separate lifecycle |
| F-12 | MCP server configs | **DEFERRED** | Future capability | Rebuildable |
| F-13 | Phase project tracking | **REJECTED** | — | Historical only |
| F-14 | Firefly config SOP | **SUPERSEDED** | Folded into FINANCE_DEPLOY_RUNBOOK.md | — |
| F-15 | Session logs | **REJECTED** | — | Transient |
| F-16 | Archived plans | **REJECTED** | — | Fully superseded |
| F-17 | Phase-specific guides | **REJECTED** | — | Transient |

## Phase Progress

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Audit matrix + loop registration | COMPLETE (bbe30a3, c768e63) |
| P1 | 8 extract_now docs (Move A) | COMPLETE (c768e63) |
| P2 | Binding updates (health, backup, secrets) | COMPLETE (this commit) |
| P3 | Pillar structure (README, ARCHITECTURE, EXTRACTION_STATUS) | COMPLETE (this commit) |
| P4 | Validate + close | IN PROGRESS |

## Binding Updates (P2)

| Binding | Change | Status |
|---------|--------|--------|
| `services.health.yaml` | Add firefly-iii, paperless-ngx, ghostfolio probes | COMPLETE |
| `backup.inventory.yaml` | Enable `app-firefly` | COMPLETE |
| `secrets.namespace.policy.yaml` | Add SIMPLEFIN_ACCESS_URL, GHOSTFOLIO_* keys | COMPLETE |
