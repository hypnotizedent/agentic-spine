---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-pillar-overview
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
---

# Finance Pillar

> Business-domain pillar for financial operations: expense tracking, bank sync, receipt management, and business reporting.

## Classification

**PILLAR** (per EXTRACTION_PROTOCOL.md) — 7+ containers, business domain, separate lifecycle.

## Services

| Service | Host | Port | Domain | Status |
|---------|------|------|--------|--------|
| Firefly III | finance-stack (VM 211) | 8080 | firefly.ronny.works | ACTIVE |
| Paperless-ngx | finance-stack (VM 211) | 8000 | docs.ronny.works | ACTIVE |
| Ghostfolio | finance-stack (VM 211) | 3333 | finances.ronny.works | UNCONFIGURED |
| PostgreSQL 16 | finance-stack (VM 211) | 5432 | internal | ACTIVE |
| Redis 7 | finance-stack (VM 211) | 6379 | internal | ACTIVE |
| Data Importer | finance-stack (VM 211) | 8091 | local only | ACTIVE |
| Cron (sync) | finance-stack (VM 211) | — | — | ACTIVE |

## Integration Points

- **SimpleFIN Bridge** — daily bank sync for 16 accounts (see `FINANCE_SIMPLEFIN_PIPELINE.md`)
- **n8n (VM 202)** — webhook-triggered Firefly→Mint OS expense sync (see `FINANCE_N8N_WORKFLOWS.md`)
- **Mint OS (docker-host)** — business expense tracking and job costing
- **Synology NAS** — backup destination via NFS

## Key Documentation

| Document | Path | Scope |
|----------|------|-------|
| Stack Architecture | `docs/brain/lessons/FINANCE_STACK_ARCHITECTURE.md` | Service topology, compose, volumes |
| SimpleFIN Pipeline | `docs/brain/lessons/FINANCE_SIMPLEFIN_PIPELINE.md` | Bank sync, account mapping |
| n8n Workflows | `docs/brain/lessons/FINANCE_N8N_WORKFLOWS.md` | Automation workflows |
| Backup & Restore | `docs/brain/lessons/FINANCE_BACKUP_RESTORE.md` | DB backup/restore procedures |
| Account Topology | `docs/brain/lessons/FINANCE_ACCOUNT_TOPOLOGY.md` | 21-account registry |
| Deploy Runbook | `docs/brain/lessons/FINANCE_DEPLOY_RUNBOOK.md` | Deployment procedures |
| Reconciliation | `docs/brain/lessons/FINANCE_RECONCILIATION.md` | Sync gap detection |
| Troubleshooting | `docs/brain/lessons/FINANCE_TROUBLESHOOTING.md` | Debug procedures |
| Extraction Matrix | `docs/governance/FINANCE_LEGACY_EXTRACTION_MATRIX.md` | Extraction tracking |

## Secrets

- **Infisical project:** `finance-stack` (ID: `4c34714d-6d85-4aa6-b8df-5a9505f3bcef`)
- **~14 keys** covering Firefly, Paperless, Ghostfolio, SimpleFIN, PostgreSQL
- **Namespace:** `/spine/services/finance` (FIREFLY_PAT), `/spine/services/paperless` (PAPERLESS_API_TOKEN)

## Known Gaps

- Ghostfolio unconfigured (no investment data)
- No Prometheus/Grafana observability
- ~~Shared VM with Mint OS~~ — resolved: finance migrated to dedicated VM 211
- Receipt→Firefly n8n workflow blocked (IF node routing bug)
