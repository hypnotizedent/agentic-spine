---
status: planned
owner: "@ronny"
created: "2026-03-03"
scope: tax-legal-domain-runbook
domain: tax-legal
gap: GAP-OP-1425
loop: LOOP-TAXLEGAL-W1-AGENT-BOUNDARY-CONTRACTS-20260303
plan: PLAN-TAX-LEGAL-OPS-WORKER-20260303
---

# Tax-Legal Domain Runbook

> Operator procedures and incident playbooks for the tax-legal domain.
> Status: planned (Wave 1 design-only artifact).

## 1. Domain Overview

The tax-legal domain provides compliance coordination and citation-strict research
for business lifecycle operations. It does not provide legal or tax advice.

### Key Surfaces

| Surface | Status | Purpose |
|---------|--------|---------|
| Case lifecycle | planned | Intake through closeout case management |
| Source registry | planned | Primary government source versioning |
| Deadline tracking | planned | Filing deadline management and escalation |
| Privacy controls | planned | PII scanning, redaction, retention |
| Filing packets | planned | Draft packet assembly for human review |

### Authoritative Contracts

| Contract | Path |
|----------|------|
| Agent contract | `ops/agents/tax-legal-agent.contract.md` |
| Boundary contract | `docs/governance/TAX_LEGAL_AGENT_BOUNDARY.md` |
| Case lifecycle | `ops/bindings/taxlegal.case.lifecycle.contract.yaml` |
| Source registry | `ops/bindings/taxlegal.sources.registry.yaml` |
| Citation policy | `ops/bindings/taxlegal.citation.contract.yaml` |
| Privacy contract | `ops/bindings/taxlegal.privacy.contract.yaml` |
| Retention contract | `ops/bindings/taxlegal.retention.contract.yaml` |
| Deadline contract | `ops/bindings/taxlegal.deadline.contract.yaml` |

## 2. Session Entry

```bash
# Future: when DOMAIN-TAXLEGAL-01 terminal role is active
./bin/ops cap run session.start
# select DOMAIN-TAXLEGAL-01 via worker picker or env override
```

## 3. Common Operations (Planned)

### 3.1 Create a New Case

```bash
# Planned capability (not yet implemented)
./bin/ops cap run taxlegal.case.intake -- --type <case_type> --jurisdiction 33441
```

Case types: `formation`, `address_amendment`, `local_compliance`, `enforcement_remediation`, `ongoing_compliance`, `closure`.

### 3.2 Check Deadline Status

```bash
# Planned capability
./bin/ops cap run taxlegal.deadlines.status
```

### 3.3 Sync Primary Sources

```bash
# Planned capability (mutating, requires manual approval)
./bin/ops cap run taxlegal.sources.sync
```

### 3.4 Generate Filing Packet Draft

```bash
# Planned capability
./bin/ops cap run taxlegal.packet.generate -- --case-id CASE-TAXLEGAL-YYYYMMDD-####
```

## 4. Incident Playbooks

### 4.1 Boundary Violation Detected

**Symptom:** D333 gate failure or manual report of forbidden advice language.

**Response:**
1. Place affected case in `blocked` state.
2. Review offending output for actual advisory content vs. false positive.
3. If confirmed violation: file GAP, correct output, add regression evidence.
4. If false positive: adjust gate pattern matching and re-run.

### 4.2 Source Drift on Active Case

**Symptom:** `source_changed` event on a source referenced by an open case.

**Response:**
1. Mark affected cases as `revalidation_required`.
2. Run `taxlegal.sources.diff` to identify changed content.
3. Re-run research pipeline for impacted claims.
4. If deadline-impacting: escalate to operator immediately.

### 4.3 PII Leakage in Case Artifact

**Symptom:** D337 gate failure or `taxlegal.privacy.scan` alert.

**Response:**
1. Immediate: apply `taxlegal.privacy.redact` to affected artifacts.
2. Review log/trace outputs for PII exposure.
3. File incident gap with evidence.
4. Verify retention contract is enforced for affected artifacts.

### 4.4 Missed Deadline Escalation

**Symptom:** Deadline within escalation window without operator acknowledgment.

**Response:**
1. Check `taxlegal.deadlines.status` for current state.
2. Verify notification pipeline delivered alert.
3. If notification failed: manual operator notification.
4. Document in case record with timestamp.

## 5. Verification

```bash
# Planned: domain-specific verification
./bin/ops cap run verify.run -- domain tax-legal

# Planned: full pack verification
./bin/ops cap run verify.pack.run tax-legal
```

## 6. Dependencies

| Dependency | Domain | Usage |
|-----------|--------|-------|
| `finance-agent` | finance | Revenue/payout data for tax exposure |
| `communications-agent` | communications | Draft notice preview and delivery log |
| `microsoft-agent` | microsoft | Calendar sync for deadlines (planned) |
| Infisical | infrastructure | Secret path references for PII |
| Paperless-ngx | finance | Document attachment for case packets |
