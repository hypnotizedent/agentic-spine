# tax-legal-agent Contract

> **Status:** experimental
> **Domain:** tax-legal-ops
> **Owner:** @ronny
> **Created:** 2026-03-03
> **Gap:** GAP-OP-1422
> **Loop:** LOOP-TAXLEGAL-W1-AGENT-BOUNDARY-CONTRACTS-20260303
> **Plan:** PLAN-TAX-LEGAL-OPS-WORKER-20260303

---

## Identity

- **Agent ID:** tax-legal-agent
- **Domain:** tax-legal-ops (compliance coordination, citation-strict research, business lifecycle operations)
- **Implementation:** experimental (Wave 2 runtime — 6 capabilities active)
- **Registry:** `ops/bindings/agents.registry.yaml` (active entry)

## Role Definition

The tax-legal-agent is a **compliance coordinator and citation-strict researcher**. It is explicitly **not** a decision authority for legal or tax matters. All outputs are research artifacts, draft packets, and structured checklists that require human professional review before any external action.

## Operating Model (Supervisor + Narrow Workers)

| Worker | Purpose |
|--------|---------|
| `taxlegal-supervisor` | Creates/owns case lifecycle, dispatches to workers, assembles final packet |
| `taxlegal-intake` | Triages requests into case types, emits intake checklist |
| `taxlegal-source-librarian` | Syncs/versions primary sources with SHA-256 tracking |
| `taxlegal-researcher` | Citation-anchored answers only, enforces `unknown` fallback |
| `taxlegal-filing-coordinator` | Deadline tracking, required IDs checklist, draft packet composition |
| `taxlegal-privacy-gate` | PII scrubbing, secret-path references only, retention enforcement |
| `taxlegal-human-reviewer` | Attorney/CPA memo generation, risk classification |

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Case lifecycle management (intake through closeout) | Mailroom case artifacts |
| Primary source ingestion and versioning | Source registry + local snapshots |
| Citation-strict research with unknown-state enforcement | Research pipeline |
| Deadline tracking and filing packet drafting | Deadline contract + calendar sync |
| PII scanning and redaction enforcement | Privacy contract |
| Attorney/CPA review memo generation | Human review pipeline |
| Business lifecycle playbooks (formation through closure) | Governance playbooks |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Stack deployment | No dedicated VM in v1 (spine-native execution) |
| Health probes | `ops/bindings/services.health.yaml` (future) |
| Secrets | Infisical path references only (no direct secret storage in case artifacts) |
| Domain routing | `ops/bindings/domain.taxonomy.bridge.contract.yaml` |
| Operational runbooks | `docs/governance/domains/tax-legal/RUNBOOK.md` |
| Finance data | `finance-agent` tools (Firefly III, Paperless-ngx, Ghostfolio) |
| Communications | `communications-agent` capabilities (send preview, delivery log) |
| Calendar sync | `microsoft-agent` capabilities (planned) |

## Defers to Human Professional

| Concern | Authority |
|---------|-----------|
| Definitive legal advice | Licensed attorney |
| Definitive tax positions | Licensed CPA or enrolled agent |
| Filing submission to government agencies | Human operator |
| Entity restructuring decisions | Licensed professional + operator |
| Privacy/anonymity strategy decisions | Operator with professional counsel |

## Planned Capabilities (Not Implemented)

### Intake + Case Lifecycle

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.case.intake` | mutating | auto | Create case envelope + intake checklist |
| `taxlegal.case.status` | read-only | auto | Read consolidated case progress |
| `taxlegal.case.closeout` | mutating | manual | Finalize case with review evidence |

### Source + Research

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.sources.sync` | mutating | manual | Pull + hash primary sources by registry |
| `taxlegal.sources.diff` | read-only | auto | Show source drift and reindex requirements |
| `taxlegal.research.answer` | read-only | auto | Citation-required response with unknown fallback |
| `taxlegal.research.compare` | read-only | auto | Jurisdiction/requirement comparison matrix |

### Deadlines + Packet Drafting

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.deadlines.refresh` | mutating | auto | Recompute due dates/escalations |
| `taxlegal.deadlines.status` | read-only | auto | Upcoming deadlines and risk levels |
| `taxlegal.packet.generate` | mutating | auto | Assemble draft filing packet |
| `taxlegal.memo.attorney_cpa` | mutating | auto | Generate review memo with open questions |

### Privacy + Compliance Guards

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.privacy.scan` | read-only | auto | Detect PII leakage risk in case artifacts |
| `taxlegal.privacy.redact` | mutating | manual | Apply governed redaction policy |
| `taxlegal.retention.enforce` | mutating | manual | Purge/archive per retention contract |

## Spine Capabilities (Observability Layer)

Planned spine capabilities for tax-legal observability (not yet registered):

| Capability | Description |
|------------|-------------|
| `taxlegal.case.status` | Case lifecycle status across all open cases |
| `taxlegal.deadlines.status` | Upcoming deadlines and risk levels |
| `taxlegal.sources.diff` | Source drift detection |

## Authoritative Contracts

| File | Purpose |
|------|---------|
| `ops/bindings/taxlegal.case.lifecycle.contract.yaml` | Case states and transitions |
| `ops/bindings/taxlegal.sources.registry.yaml` | Primary source inventory |
| `ops/bindings/taxlegal.citation.contract.yaml` | Citation strictness policy |
| `ops/bindings/taxlegal.privacy.contract.yaml` | PII and privacy controls |
| `ops/bindings/taxlegal.retention.contract.yaml` | Retention windows and purge rules |
| `ops/bindings/taxlegal.deadline.contract.yaml` | Deadline model and escalation |
| `ops/bindings/taxlegal.lifecycle.events.contract.yaml` | Business lifecycle event taxonomy |
| `ops/bindings/taxlegal.enforcement.response.contract.yaml` | Enforcement response workflow |
| `ops/bindings/taxlegal.jurisdiction.profile.33441.yaml` | Local jurisdiction baseline |
| `docs/governance/TAX_LEGAL_AGENT_BOUNDARY.md` | Allowed/forbidden behavior |
| `docs/governance/domains/tax-legal/RUNBOOK.md` | Operator procedures |

## Invocation

Planned: on-demand via Claude Code session with `DOMAIN-TAXLEGAL-01` terminal role.
No watchers, no cron in v1. Case-driven workflow only.

## V2+ Roadmap

| Item | Description | Status |
|------|-------------|--------|
| Source RAG pipeline | Citation-strict retrieval over versioned primary sources | Planned (Wave 2) |
| Deadline calendar sync | Microsoft calendar integration for filing deadlines | Planned (Wave 3) |
| Finance connector | Firefly III revenue/payout data for tax exposure checks | Planned (Wave 4) |
| Automated reminder drafts | Communications-routed deadline reminders | Planned (Wave 4) |
