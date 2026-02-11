---
status: historical
owner: "@ronny"
last_verified: 2026-02-11
scope: extraction-audit
migrated_from: "audit of https://github.com/hypnotizedent/ronny-ops.git @ 1ea9dfa9"
parent_loop: LOOP-SPINE-CONSOLIDATION-20260210
active_loop: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction_complete: true
---

# Finance Legacy Extraction Matrix

> **Historical Capture**
>
> This document is a point-in-time extraction audit from `2026-02-11`.
> Legacy source: `https://github.com/hypnotizedent/ronny-ops.git` @ commit `1ea9dfa9`.
> Do not execute legacy commands or act on legacy paths in this document.
>
> **Current authority:** See EXTRACTION_PROTOCOL.md and LEGACY_DEPRECATION.md.

## Classification

**Finance = PILLAR** (per EXTRACTION_PROTOCOL.md decision tree)
- 7+ containers (Firefly III, PostgreSQL, Redis, Cron, Data Importer, Ghostfolio, Paperless-ngx)
- Business domain with separate lifecycle
- Requires: architecture docs, lessons, runbooks, binding files, dedicated loops

## 1. Findings (Severity Ordered)

### CRITICAL

| ID | Finding | Impact if Lost |
|----|---------|----------------|
| F-01 | **SimpleFIN bank sync pipeline** (scripts, cron, account mapping for 16 bank/credit accounts) | Bank transaction import stops; no documentation of sync configuration, account IDs, or troubleshooting |
| F-02 | **Firefly-to-Mint-OS webhook sync** (n8n workflow JSON, category mapping, API routes) | Business expense tracking breaks; job costing unavailable; no record of webhook config |
| F-03 | **Database backup procedures** (backup-finance-stack.sh, cron schedule, restore steps) | Firefly + Ghostfolio databases unrecoverable; backup currently disabled in spine |
| F-04 | **Account registry** (15+ bank/credit accounts, loan details, business categories) | Complete loss of account topology; manual reconstruction from bank statements required |

### HIGH

| ID | Finding | Impact if Lost |
|----|---------|----------------|
| F-05 | **Docker compose topology** (service graph, volume mounts, network config, env vars) | Stack rebuild requires reverse-engineering from running containers |
| F-06 | **Deployment runbook** (pre-flight checks, health validation, rollback) | Deploy becomes tribal knowledge |
| F-07 | **SimpleFIN setup guide + credentials path** (Infisical paths, SimpleFIN bridge token) | Reconnection to SimpleFIN requires contacting provider; $1.50/month/account at risk |
| F-08 | **Receipt scanning workflow** (Paperless OCR, scan-to-paperless.sh, Paperless-Firefly integration) | Receipt automation lost; OCR pipeline undocumented |
| F-09 | **Reconciliation scripts** (reconciliation-report.sh, sync-missing.sh, backfill-all.sh) | No automated way to detect transaction gaps or reconcile Firefly vs Mint OS |
| F-10 | **Troubleshooting guide** (TRB_FINANCE_STACK.md) | Debug procedures lost; incident response degraded |

### MEDIUM

| ID | Finding | Impact if Lost |
|----|---------|----------------|
| F-11 | **Mail-archiver stack** (17,987 archived emails, PostgreSQL 17, separate compose) | Email archive inaccessible; not critical to finance ops |
| F-12 | **MCP server configs** (Firefly 43-tool, Paperless 12-tool) | Agent tooling configs lost; rebuildable from API docs |
| F-13 | **Phase project tracking** (phases 0-5 docs) | Historical project context lost; no operational impact |
| F-14 | **Firefly configuration SOP** | Setup procedures lost; rebuildable but time-consuming |

### LOW

| ID | Finding | Impact if Lost |
|----|---------|----------------|
| F-15 | **Session logs** (7+ handoff docs) | Historical context only |
| F-16 | **Archived plans** (IMPLEMENTATION_PLAN, CLAUDE_CODE_COMMANDS, etc.) | Fully superseded |
| F-17 | **Phase-specific setup guides** (firefly-phase3-setup.md) | Transient project docs |

## 2. Coverage Matrix (Spine vs Legacy)

| Operational Need | Legacy Coverage | Spine Coverage | Gap |
|-----------------|----------------|----------------|-----|
| **Service registration** | docker-compose.yml | docker.compose.targets.yaml (stub) | PARTIAL — no service-level detail |
| **Domain routing** | README references | DOMAIN_ROUTING_REGISTRY.yaml (good) | COVERED |
| **Secrets inventory** | .env.example + Infisical paths | secrets.inventory.yaml (project-level) | PARTIAL — key-level enumeration missing |
| **Secrets namespace** | Infisical folders | secrets.namespace.policy.yaml (FIREFLY_PAT only) | PARTIAL — other keys missing |
| **Health checks** | deploy script has health validation | services.health.yaml — NONE | MISSING |
| **Backup procedures** | BACKUP.md + backup scripts + cron | backup.inventory.yaml (disabled) | MISSING — backup disabled, no restore docs |
| **Bank sync pipeline** | Scripts + cron + account mapping | NONE | MISSING |
| **Deployment runbook** | RUNBOOK_DEPLOY.md + deploy script | NONE | MISSING |
| **Troubleshooting** | TRB_FINANCE_STACK.md | NONE | MISSING |
| **Integration docs** | FINANCE_CONTEXT.md + runbooks | INFRASTRUCTURE_MAP.md (API section) | PARTIAL — API documented, workflows not |
| **n8n workflows** | Exported JSON + CONTRACT.md | NONE | MISSING |
| **Reconciliation** | 3 reconciliation scripts | NONE | MISSING |
| **Account topology** | REF_ACCOUNT_REGISTRY.md | NONE | MISSING |
| **Category mapping** | REF_CATEGORY_MAPPING.md + JSON config | NONE (referenced in INFRASTRUCTURE_MAP) | MISSING |
| **Recovery ordering** | Deploy runbook | REBOOT_HEALTH_GATE.md (Phase 4 stub) | PARTIAL |
| **Ghostfolio** | docker-compose.yml | docker.compose.targets.yaml (mention only) | MISSING |
| **Paperless** | Scripts + config | Domain routing only | MISSING |
| **Monitoring/metrics** | NONE | NONE | MISSING (both) |

**Coverage summary:** 1 COVERED, 4 PARTIAL, 13 MISSING

## 3. Loss-if-Deleted Report

### Immediate Loss (if legacy repo deleted today)

| Severity | What's Lost | Reconstructable? | Blast Radius |
|----------|-------------|-------------------|--------------|
| CRITICAL | SimpleFIN pipeline (sync scripts, account mapping, cron) | Partially — running containers have config, but scripts/docs gone | Bank imports stop on next failure; no troubleshooting reference |
| CRITICAL | Firefly-Mint OS sync (n8n workflow JSON, webhook config) | No — workflow JSON is the only source; running n8n has it but no backup | Business expense tracking breaks; Mint OS job costing offline |
| CRITICAL | Database backup/restore procedures | No — backup script logic, cron schedule, retention policy all lost | Next DB failure = potential data loss; backup is currently DISABLED in spine |
| CRITICAL | Account registry (16 accounts, loans, balances) | Partially — Firefly has accounts but not the mapping/context doc | Account reconciliation requires manual bank-by-bank discovery |
| HIGH | Docker compose topology + env template | Yes — running stack can be reverse-engineered | Rebuild time: hours instead of minutes |
| HIGH | Deployment + troubleshooting runbooks | No — tribal knowledge only | Incident response time increases significantly |
| HIGH | Receipt scanning pipeline | Partially — running Paperless has config | OCR workflow undocumented |
| MEDIUM | Mail archiver config | Yes — simple compose stack | Minor rebuild effort |
| MEDIUM | MCP server configs | Yes — rebuildable from API docs | Agent tooling temporarily unavailable |
| LOW | Session logs, archived plans | No — but no operational value | None |

### What Can Be Reconstructed from Current Spine

- Domain routing (DOMAIN_ROUTING_REGISTRY.yaml — complete)
- Infisical project structure (secrets.inventory.yaml — project-level)
- API integration overview (INFRASTRUCTURE_MAP.md — Firefly section)
- Recovery ordering (REBOOT_HEALTH_GATE.md — Phase 4)
- Secrets migration framework (capabilities.yaml — P5 finance caps)

### Irreplaceable Artifacts

1. **n8n workflow JSON exports** — the Firefly-to-Mint-OS sync workflow (`upgFmdx32jnsW30J`) and Receipt-to-Firefly workflow are only in the legacy repo and the running n8n instance. If both are lost, the automation logic is gone.
2. **SimpleFIN Python importer** (`simplefin-to-firefly.py`, 321 lines) — custom bank-to-Firefly mapping logic with account-specific handling.
3. **Account registry with business context** — the mapping of which accounts serve which business function, loan terms, and reconciliation notes.

## 4. Extraction Decision Matrix

| ID | Legacy Artifact | Disposition | Spine Target Path | Reason |
|----|----------------|-------------|-------------------|--------|
| F-01 | SimpleFIN sync scripts + account mapping | **extract_now** | `docs/brain/lessons/FINANCE_SIMPLEFIN_PIPELINE.md` | Move A — doc-only snapshot; scripts are tangled with env vars |
| F-02 | Firefly-Mint OS n8n workflows (JSON) | **extract_now** | `docs/brain/lessons/FINANCE_N8N_WORKFLOWS.md` | Move A — document workflow logic, webhook config, category mapping |
| F-03 | Backup/restore procedures | **extract_now** | `docs/brain/lessons/FINANCE_BACKUP_RESTORE.md` | Move A — document procedures + enable backup in backup.inventory.yaml |
| F-04 | Account registry | **extract_now** | `docs/brain/lessons/FINANCE_ACCOUNT_TOPOLOGY.md` | Move A — doc-only; no values, just structure and business context |
| F-05 | Docker compose topology | **extract_now** | `docs/brain/lessons/FINANCE_STACK_ARCHITECTURE.md` | Move A — service graph, dependencies, volume layout |
| F-06 | Deployment runbook | **extract_now** | `docs/brain/lessons/FINANCE_DEPLOY_RUNBOOK.md` | Move A — rewrite for spine-native patterns |
| F-07 | SimpleFIN setup + credentials | **extract_now** | Fold into FINANCE_SIMPLEFIN_PIPELINE.md | Move A — credential paths only (Infisical refs) |
| F-08 | Receipt scanning workflow | **defer** | future loop | Low operational urgency; Paperless is running |
| F-09 | Reconciliation scripts | **extract_now** | `docs/brain/lessons/FINANCE_RECONCILIATION.md` | Move A — document logic; actual scripts are Move B candidates later |
| F-10 | Troubleshooting guide | **extract_now** | `docs/brain/lessons/FINANCE_TROUBLESHOOTING.md` | Move A — rewrite from TRB_FINANCE_STACK.md |
| F-11 | Mail-archiver | **defer** | future loop | Not core finance; separate lifecycle |
| F-12 | MCP server configs | **defer** | future capability | Rebuildable; not urgent |
| F-13 | Phase project tracking | **reject** | — | Historical; no operational value |
| F-14 | Firefly config SOP | **superseded** | Fold into FINANCE_DEPLOY_RUNBOOK.md | Covered by deploy runbook |
| F-15 | Session logs | **reject** | — | Transient; no value |
| F-16 | Archived plans | **reject** | — | Fully superseded |
| F-17 | Phase-specific guides | **reject** | — | Transient |

**Summary:** 8 extract_now, 3 defer, 4 reject, 2 superseded

## 5. Proposed Spine-Native Doc Set

### Pillar Structure (per EXTRACTION_PROTOCOL.md)

Since finance is classified as a **Pillar**, the extraction protocol requires:

```
docs/pillars/finance/README.md              — overview + service inventory
docs/pillars/finance/ARCHITECTURE.md        — technical design + dataflow
docs/pillars/finance/EXTRACTION_STATUS.md   — progress tracking
```

### Lessons (operational knowledge)

```
docs/brain/lessons/FINANCE_STACK_ARCHITECTURE.md    — service topology, compose, volumes
docs/brain/lessons/FINANCE_SIMPLEFIN_PIPELINE.md    — bank sync, account mapping, cron
docs/brain/lessons/FINANCE_N8N_WORKFLOWS.md         — webhook sync, category mapping
docs/brain/lessons/FINANCE_BACKUP_RESTORE.md        — DB backup/restore procedures
docs/brain/lessons/FINANCE_ACCOUNT_TOPOLOGY.md      — account registry, business context
docs/brain/lessons/FINANCE_DEPLOY_RUNBOOK.md        — deploy + config SOP
docs/brain/lessons/FINANCE_RECONCILIATION.md        — reconciliation logic + scripts
docs/brain/lessons/FINANCE_TROUBLESHOOTING.md       — debug procedures
```

### Governance (extraction tracking)

```
docs/governance/FINANCE_LEGACY_EXTRACTION_MATRIX.md — this document (promoted)
```

### Binding Updates (existing files)

```
ops/bindings/services.health.yaml           — add Firefly, Paperless, Ghostfolio health checks
ops/bindings/backup.inventory.yaml          — enable app-firefly backup
ops/bindings/secrets.namespace.policy.yaml  — add missing finance keys
```

## 6. Loop Trace

### Current Trace
- **Parent loop:** LOOP-SPINE-CONSOLIDATION-20260210 (general consolidation)
- **Related loop:** LOOP-MEDIA-LEGACY-EXTRACTION-20260211 (pattern precedent)

### Recommendation
**Create dedicated loop:** `LOOP-FINANCE-LEGACY-EXTRACTION-YYYYMMDD`
- Severity: HIGH
- Reason: Finance is a Pillar classification requiring dedicated structure, 8 extract_now items, and phased execution
- LOOP-SPINE-CONSOLIDATION is too general (hygiene focus, not domain extraction)

### Proposed Phases for Dedicated Loop

- **P0:** Register loop + this audit matrix (this proposal)
- **P1:** Extract critical docs (F-01 through F-04) — Move A doc-only snapshots
- **P2:** Extract high docs (F-05, F-06, F-09, F-10) — Move A rewrites
- **P3:** Create pillar structure (docs/pillars/finance/) + binding updates
- **P4:** Validate via spine.verify + close with receipt-linked summary

## 7. Gap Registration (Proposed)

```yaml
- id: GAP-OP-093
  severity: high
  title: "Finance stack has no health checks, backup disabled, and no operational runbooks in spine"
  parent_loop: LOOP-SPINE-CONSOLIDATION-20260210
  recommended_loop: LOOP-FINANCE-LEGACY-EXTRACTION
  status: open
  notes: >
    Finance stack (Firefly III, Paperless, Ghostfolio) on docker-host VM 200 has:
    - Zero health check endpoints in services.health.yaml
    - Backup disabled in backup.inventory.yaml
    - No operational runbooks in spine (8 exist in legacy only)
    - No pillar structure per EXTRACTION_PROTOCOL.md
    Coverage: 1 covered, 4 partial, 13 missing operational needs.
```

## Appendix: Legacy Source Evidence

- **Repository:** https://github.com/hypnotizedent/ronny-ops.git
- **Commit:** `1ea9dfa9` ("docs(spine): distinguish agent receipts vs runtime receipts")
- **Local read-only path:** legacy clone (D30 — do not execute from here)
- **Finance root:** `ronny-ops/finance/` (150+ artifacts)
- **Audit date:** 2026-02-11
- **Auditor:** Terminal E (governed session)
