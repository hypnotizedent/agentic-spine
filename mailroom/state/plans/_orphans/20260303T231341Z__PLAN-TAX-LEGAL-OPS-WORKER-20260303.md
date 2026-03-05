# PLAN-TAX-LEGAL-OPS-WORKER-20260303

> Coordinator specification for `LOOP-TAX-LEGAL-OPS-WORKER-SPEC-20260303`.
> Mode: design-only (no runtime implementation in this plan).
> Date: 2026-03-03.

## W0 Topology Baseline (Captured)

| Surface | Baseline Snapshot |
|---|---|
| `/code` roots | `agentic-spine`, `workbench`, `mint-modules` (+ runtime dirs) |
| Canonical runtime | `agentic-spine` with governed `ops cap run` + receipts |
| Mailroom model | Externalized runtime root + in-repo governance stubs/contracts |
| Finance domain | `finance-agent` active, finance stack on VM 211 |
| Existing tax/compliance exposure | finance queue + filing packet tooling, no dedicated tax/legal worker domain |

Session evidence (baseline):
- `CAP-20260303-031126__session.start__Rnd4t75085`
- `CAP-20260303-031118__session.role.override__Rf2ec60315`

---

## 1. Outcome Definition

Create a governed Tax & Legal Ops worker system that functions as a compliance coordinator and research engine, not a law/tax decision-maker.

### 1A. Program Vector (What This Is Becoming)

This domain is explicitly a business lifecycle operations system with privacy-aware compliance controls:

1. Business start: entity formation and initial compliance setup.
2. Business amend/operate: address changes, licensing, recurring deadlines, and incident response (for example zoning/code-enforcement notices).
3. Business close: dissolution/closure workflow with filing and record-retention obligations.
4. Privacy/anonymity: minimize public personal exposure while preserving full legal/federal reporting compliance.

### Success Profile

1. Case-driven workflow (not freeform chat) with receipts and source evidence.
2. Citation-strict research against primary sources with explicit unknown states.
3. Deadline + packet orchestration integrated with finance and communications surfaces.
4. Human attorney/CPA review remains final authority.

### Explicit Non-Goals

1. No autonomous legal advice or definitive tax positions.
2. No automatic filing submission in v1.
3. No broad doc ingest across untrusted/non-primary sources in v1.
4. No acceptance of model/chat output as authority unless verified against primary government sources.

---

## 2. Operating Model (Supervisor + Narrow Workers)

### A. `taxlegal-supervisor` (Coordinator)

- Creates/owns case lifecycle.
- Dispatches to narrow workers.
- Assembles final packet: findings, citations, drafts, unresolved questions.

### B. `taxlegal-intake`

- Triage user requests into case types:
  - IRS / federal tax
  - Florida state tax/compliance
  - local city/county licensing/tax
  - entity/corporate filings and notices
  - contract/compliance drafting support
- Emits scoped intake checklist and missing-info prompts.

### C. `taxlegal-source-librarian`

- Syncs/versions primary sources (PDF + HTML snapshots).
- SHA-256 diff + content hash tracking.
- Re-index trigger only on deterministic source drift.

### D. `taxlegal-researcher`

- Answers only with citation anchors.
- Enforces `unknown` response when confidence or citations are insufficient.
- Produces compare tables across jurisdictions and effective dates.

### E. `taxlegal-filing-coordinator`

- Deadline tracking, required IDs checklist, packet draft composition.
- No submission authority in v1 (draft-only).

### F. `taxlegal-privacy-gate`

- PII scrubbing for prompts/logs.
- Secret-path references only (no EIN/SSN in artifacts).
- Retention timers and purge policies.

### G. `taxlegal-human-reviewer`

- Produces attorney/CPA memo.
- Emits risk class: green/yellow/red with unresolved-item list.

---

## 3. Contract Pack (Proposed Artifacts)

### 3.1 Agent + Boundary Contracts

| Target File | Type | Purpose |
|---|---|---|
| `ops/agents/tax-legal-agent.contract.md` | new (proposed) | Domain ownership, defers, capabilities, invocation model |
| `docs/governance/TAX_LEGAL_AGENT_BOUNDARY.md` | new (proposed) | Allowed/forbidden behavior, advice boundary lock |
| `docs/governance/domains/tax-legal/RUNBOOK.md` | new (proposed) | Operator procedures and incident playbooks |
| `docs/governance/domains/tax-legal/CAPABILITIES.md` | new (generated/projection later) | Domain capability catalog |

### 3.2 Data + Lifecycle Contracts

| Target File | Type | Purpose |
|---|---|---|
| `ops/bindings/taxlegal.case.lifecycle.contract.yaml` | new (proposed) | Case states, transitions, required artifacts |
| `ops/bindings/taxlegal.lifecycle.events.contract.yaml` | new (proposed) | Start/amend/operate/close event taxonomy and mandatory evidence |
| `ops/bindings/taxlegal.sources.registry.yaml` | new (proposed) | Primary-source inventory with hash/version metadata |
| `ops/bindings/taxlegal.citation.contract.yaml` | new (proposed) | Citation strictness, anchor requirements, unknown policy |
| `ops/bindings/taxlegal.privacy.contract.yaml` | new (proposed) | PII classes, redaction modes, log policies |
| `ops/bindings/taxlegal.retention.contract.yaml` | new (proposed) | Retention windows, purge and archival rules |
| `ops/bindings/taxlegal.deadline.contract.yaml` | new (proposed) | Deadline model, calendar sync and escalation windows |
| `ops/bindings/taxlegal.enforcement.response.contract.yaml` | new (proposed) | Code-enforcement/zoning response workflow and escalation evidence |
| `ops/bindings/taxlegal.jurisdiction.profile.33441.yaml` | new (proposed) | Deerfield Beach/Broward default jurisdiction profile for local routing |

### 3.3 Registry + Routing Deltas (Planned, Not Applied)

| Target File | Change |
|---|---|
| `ops/bindings/agents.registry.yaml` | add `tax-legal-agent` (implementation_status: planned), routing keywords |
| `ops/bindings/terminal.role.contract.yaml` | add `DOMAIN-TAXLEGAL-01` planned role |
| `ops/bindings/domain.taxonomy.bridge.contract.yaml` | add `tax-legal` catalog/planned-runtime mapping |
| `docs/governance/domains/CAPABILITIES_INDEX.md` | include tax-legal domain after capability registration |

---

## 4. Capability Surface (Planned)

All names below are proposed and not implemented.

### 4.1 Intake + Case Lifecycle

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.case.intake` | mutating | auto | Create case envelope + intake checklist |
| `taxlegal.case.status` | read-only | auto | Read consolidated case progress |
| `taxlegal.case.closeout` | mutating | manual | Finalize case with review evidence |

### 4.2 Source + Research

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.sources.sync` | mutating | manual | Pull + hash primary sources by registry |
| `taxlegal.sources.diff` | read-only | auto | Show source drift and reindex requirements |
| `taxlegal.research.answer` | read-only | auto | Citation-required response with unknown fallback |
| `taxlegal.research.compare` | read-only | auto | Jurisdiction/requirement comparison matrix |

### 4.3 Deadlines + Packet Drafting

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.deadlines.refresh` | mutating | auto | Recompute due dates/escalations |
| `taxlegal.deadlines.status` | read-only | auto | Upcoming deadlines and risk levels |
| `taxlegal.packet.generate` | mutating | auto | Assemble draft filing packet + required IDs checklist |
| `taxlegal.memo.attorney_cpa` | mutating | auto | Generate review memo with open questions |

### 4.4 Privacy + Compliance Guards

| Capability | Safety | Approval | Purpose |
|---|---|---|---|
| `taxlegal.privacy.scan` | read-only | auto | Detect PII leakage risk in case artifacts |
| `taxlegal.privacy.redact` | mutating | manual | Apply governed redaction policy |
| `taxlegal.retention.enforce` | mutating | manual | Purge/archive per retention contract |

---

## 5. Mailroom + Case Artifact Contract

### 5.1 Canonical Case Pathing (Proposed)

```text
runtime/domain-state/taxlegal/cases/
  CASE-TAXLEGAL-YYYYMMDD-####/
    intake.md
    checklist.yaml
    source-registry.lock.yaml
    sources/
      irs/
      florida/
      local/
    research/
      answers.md
      citations.json
    drafts/
      filing-packet.md
      attorney-cpa-memo.md
      outbound-emails/
    risk/
      risk-classification.yaml
    receipt.md
```

### 5.2 Lifecycle States

1. `intake`
2. `sources_pending`
3. `research_in_progress`
4. `draft_packet_ready`
5. `human_review_required`
6. `ready_for_external_filing`
7. `closed`
8. `blocked`

### 5.3 Outbox Routing (Proposed)

- `mailroom/outbox/finance/tax-legal/` for case summaries tied to finance deadlines.
- `mailroom/outbox/reports/tax-legal/` for audits and periodic posture exports.
- `mailroom/outbox/communications/` for reviewed outbound comms drafts (not direct send).

---

## 6. Source System Design (Citation-Strict RAG)

### 6.1 Source Classes (v1)

1. IRS forms/instructions/publications and official FAQs.
2. Florida DOR and Sunbiz official pages/forms.
3. Local city/county tax receipt/business licensing pages.
4. FinCEN/public federal guidance where applicable.

### 6.1A Jurisdiction Starter Set (33441 Profile)

`33441` is treated as a ZIP profile for Deerfield Beach, Florida (Broward County).

v1 starter jurisdictions:

1. Federal (IRS + FinCEN/public federal guidance where applicable).
2. Florida state (Florida Department of Revenue + Sunbiz/Division of Corporations).
3. Broward County local tax/business receipt surfaces.
4. City of Deerfield Beach local tax/business receipt and licensing surfaces.

Initial intake defaults for this profile:

1. Every case starts with federal + Florida checks.
2. Local layer defaults to Broward County + Deerfield Beach.
3. Cases outside this profile are marked `jurisdiction_out_of_profile` until added to source registry.

### 6.1B Business Lifecycle Coverage Map (v1)

v1 lifecycle case families:

1. `formation`: LLC setup, registered-agent/privacy structure choices, initial state/federal checklist.
2. `address_and_registry_amendment`: principal/mailing/registered-agent updates and amendment sequencing.
3. `local_compliance`: home occupation, city/county BTR flows, zoning compatibility checks.
4. `enforcement_remediation`: notice intake, response packet, corrective action timeline, closure proof.
5. `ongoing_compliance`: annual report and recurring filing/deadline cadence.
6. `closure`: dissolution and account/license/tax closeout checklist.

### 6.5 External AI Transcript Ingestion Policy

When user-provided chat transcripts are ingested:

1. Treat all transcript claims as hypotheses.
2. Require primary-source verification before a claim can be promoted to case guidance.
3. Persist claim status as one of: `unverified`, `verified`, `conflicted`, `rejected`.
4. If unresolved, emit `human_review_required` with explicit open questions.

### 6.2 Required Metadata Fields

- `source_id`
- `jurisdiction`
- `agency`
- `doc_type`
- `effective_date`
- `last_verified`
- `retrieved_at`
- `content_sha256`
- `version_label`
- `citation_anchor` (section/page/url fragment)
- `supersedes_source_id` (optional)

### 6.3 Citation Policy

1. Every substantive claim requires at least one anchor-backed citation.
2. Out-of-citation claims must be labeled `unknown`.
3. If sources conflict, output conflict matrix and mark `human_review_required`.

### 6.4 Drift Policy

1. Hash drift triggers `source_changed` event.
2. Changed sources invalidate prior cached answer confidence for impacted cases.
3. Deadline-impact detection marks related open cases as `revalidation_required`.

---

## 7. Connector Matrix (Finance + Adjacent Agent Surfaces)

### 7.1 Finance Stack (Primary)

| Connector | Existing Surface | Planned Tax/Legal Usage |
|---|---|---|
| Firefly III | `finance-agent` tools + finance APIs | Map taxable revenue streams, contractor payout traces, period reconciliation |
| Paperless-ngx | `finance-agent` document tooling | Attach source docs/receipts/forms to case packet |
| Ghostfolio | finance stack status/holdings | Low-priority in v1; investment-only references where needed |
| `finance.stack.status` | spine capability | Health preflight before case packet generation |
| `finance.ronny.action.queue` | spine capability | Merge tax/legal tasks into owner action queue |

### 7.2 Communications + Microsoft

| Connector | Existing Surface | Planned Usage |
|---|---|---|
| `communications.send.preview` | governed comms | Draft notices/reminders with review artifacts |
| `communications.delivery.log` | governed comms | Track reminder dispatch evidence |
| `microsoft.calendar.*` (planned runtime role) | microsoft agent | Deadline calendar sync and RSVP tracking |
| `microsoft.mail.*` | microsoft agent | Optional import of official notices into case intake |

### 7.3 Mint + n8n + Observability

| Connector | Existing Surface | Planned Usage |
|---|---|---|
| `mint-agent` / finance-adapter | mint domain | Intake of billable/revenue events for tax exposure checks |
| n8n workflows | n8n domain | Optional deadline reminders/escalation automation |
| `stability.control.snapshot` | observability | Operational readiness signal for heavy sync/index jobs |
| backup/recovery domains | governance docs + capabilities | Source cache and case artifact backup posture checks |

---

## 8. Governance and Drift Gates (Proposed)

Proposed new gate IDs begin after current max `D332`.

| Gate ID | Name | Purpose |
|---|---|---|
| `D333` | taxlegal-boundary-lock | Fail if forbidden legal/tax-advice language patterns appear in generated policy templates/contracts |
| `D334` | taxlegal-source-registry-integrity | Enforce required metadata + hash fields in source registry |
| `D335` | taxlegal-citation-strictness-lock | Ensure response templates require citation anchors or explicit unknown |
| `D336` | taxlegal-case-lifecycle-lock | Enforce required artifacts for each case state transition |
| `D337` | taxlegal-privacy-redaction-lock | Ensure no direct SSN/EIN-like tokens in case outputs/log artifacts |
| `D338` | taxlegal-deadline-freshness-lock | Ensure deadline snapshots are refreshed within policy TTL |
| `D339` | taxlegal-connector-contract-lock | Validate declared connector endpoints/capabilities remain resolvable |

---

## 9. Human Review and Risk Policy

### Risk Classes

1. `green`: all requirements cited and consistent, no unresolved conflicts.
2. `yellow`: partial coverage or conflicting sources; attorney/CPA questions required.
3. `red`: missing critical source confidence, privacy concern, or high-impact legal ambiguity.

### Mandatory Human Sign-Off Triggers

1. Any filing packet generation for external submission.
2. Any source conflict on filing requirements or deadlines.
3. Any case involving entity restructuring, anonymity strategy, or ambiguous legal status.
4. Any case containing high-sensitivity PII.

---

## 10. Security, Privacy, and Retention

### 10.1 PII Policy

1. PII classes: SSN, EIN, DOB, account numbers, full addresses.
2. Store references to secrets paths; do not store secret values in case artifacts.
3. Apply redact-before-log for prompts, trace outputs, and mailroom events.

### 10.2 Retention Policy (SLA Choices + Default Selection)

SLA options for tax/legal cases:

| SLA | Ops logs | Source/citation lockfiles | Draft packet artifacts | Final reviewed packet + memo |
|---|---|---|---|---|
| `minimal` | 30 days | 180 days | 180 days | 5 years |
| `balanced` | 45 days | 365 days | 365 days | 7 years |
| `extended` | 90 days | 730 days | 730 days | 10 years |

Default selected for this plan: `balanced`.

Additional retention controls:

1. Redaction-failure artifacts are retained until manual incident close, then 90 days.
2. Purge operations require manual approval (`taxlegal.retention.enforce`).
3. Retention windows are contract-managed and change-controlled through governance docs.

---

## 11. Execution Waves (Implementation Roadmap)

This plan is intentionally implementation-ready while remaining design-only.

### Wave 1: Governance Foundations (No Runtime Code)

Outputs:
1. Agent contract draft.
2. Boundary contract.
3. Case/source/citation/privacy/retention YAML contracts.
4. Domain doc stubs + routing mapping updates (planned).
5. Business lifecycle playbooks and case templates for:
   - formation/privacy baseline
   - amendment/address correction
   - zoning or code-enforcement remediation
   - home occupation + BTR path
   - dissolution/closure

Gate to exit:
- Contract review pass by operator.

### Wave 2: Read-Only Research Runtime

Outputs:
1. `taxlegal.sources.sync|diff` read pipeline.
2. `taxlegal.research.answer|compare` citation-strict outputs.
3. `unknown` handling path and receipts.

Gate to exit:
- D334 + D335 enforce mode pass.

### Wave 3: Deadline + Draft Packets

Outputs:
1. Deadline refresh/status surfaces.
2. Draft filing packet generator.
3. Attorney/CPA memo generator.

Gate to exit:
- Case lifecycle lock (D336) and deadline freshness (D338) pass.

### Wave 4: Privacy + Connectors

Outputs:
1. PII scan/redaction + retention enforcement.
2. Finance/comms/calendar connector activation.
3. Observability and incident bundle integration.

Gate to exit:
- D337 + D339 pass and manual privacy review complete.

### Wave 5: Stabilization + Promotion

Outputs:
1. Verify route integration (`verify.pack.run tax-legal` planned).
2. Runtime role promotion from planned -> active.
3. Ops handoff and runbook closeout.

Gate to exit:
- 2 full weeks stable operation with no red-class unresolved cases.

---

## 12. Activation Commands (Future Execution)

When promoting this design to implementation:

1. Promote loop:
```bash
# edit loop status planned -> active
```

2. Register implementation plan horizon:
```bash
./bin/ops cap run planning.plans.list -- --owner @ronny
```

3. Preflight:
```bash
./bin/ops cap run session.start
./bin/ops cap run verify.run -- fast
./bin/ops cap run finance.stack.status
```

4. Post-domain verify (after domain changes):
```bash
./bin/ops cap run verify.run -- domain finance
# plus tax-legal domain verify once pack exists
```

Worker kickoff reference:

- `mailroom/state/plans/PLAN-TAXLEGAL-W1-WORKER-KICKOFF-BRIEF-20260303.md`

---

## 13. Operator Inputs Required Before Wave 1 Promotion

1. Jurisdiction profile locked: `33441` (Deerfield Beach + Broward County). Provide override only if expanding beyond this local baseline.
2. Confirm retention SLA profile (`minimal`, `balanced`, `extended`). Current default is `balanced`.
3. Confirm whether Microsoft mailbox ingestion is enabled in v1.
4. Confirm whether outbound reminder drafts should remain preview-only in v1.
5. Confirm escalation SLA defaults:
   - `yellow`: attorney/CPA review memo within 2 business days
   - `red`: same-day escalation + manual hold on packet progression

---

## 14. Go/No-Go Checklist for Implementation Start

- [ ] Loop status promoted to `active`.
- [ ] Plan reviewed and approved.
- [ ] Boundary contract approved (no legal/tax advice lock).
- [ ] Primary source registry seeded with initial authorities.
- [x] Jurisdiction profile locked (`33441` Deerfield Beach + Broward County baseline).
- [ ] Finance connector scope approved.
- [ ] Privacy/retention policy approved by operator.
- [ ] Initial gate IDs reserved and staged.

---

## 15. Natural Follow-On Loops (Planned)

1. `LOOP-TAXLEGAL-CONTRACT-PACK-IMPLEMENTATION-YYYYMMDD`
2. `LOOP-TAXLEGAL-SOURCE-INGEST-FOUNDATION-YYYYMMDD`
3. `LOOP-TAXLEGAL-DEADLINE-AND-PACKET-RUNTIME-YYYYMMDD`
4. `LOOP-TAXLEGAL-PRIVACY-RETENTION-ENFORCEMENT-YYYYMMDD`
5. `LOOP-TAXLEGAL-CONNECTOR-INTEGRATION-YYYYMMDD`
6. `LOOP-TAXLEGAL-BUSINESS-LIFECYCLE-PLAYBOOKS-YYYYMMDD`

Each loop should file child gaps for uncovered governance surfaces before code mutation, per governance brief.
