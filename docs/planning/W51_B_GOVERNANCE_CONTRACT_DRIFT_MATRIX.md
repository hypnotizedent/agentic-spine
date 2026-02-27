# W51_B: Governance + Contract Drift Matrix

**Generated:** 2026-02-27T03:50:00Z
**Mode:** READ-ONLY FORENSIC AUDIT
**Loop:** LOOP-SPINE-FOUNDATIONAL-FORENSIC-UPGRADE-20260227

---

## Executive Summary

Forensic audit of governance contracts, gate registries, capability maps, and workbench alignment. This audit identifies drift between documented contracts and runtime reality.

**Key Findings:**
- 242 gates defined (241 active, 1 retired)
- 19 domains in execution topology
- 113 capabilities require manual approval (potential human dependency)
- 125 governance documents in docs/governance/
- 12 agent contracts defined
- 577 capability scripts in ops/plugins/*/bin/
- 326 loop scopes total

---

## Governance File Inventory

### docs/governance/ (125 files)

| Category | Count | Examples |
|----------|-------|----------|
| Core Governance | 15 | AGENT_GOVERNANCE_BRIEF.md, SESSION_PROTOCOL.md, GOVERNANCE_INDEX.md |
| Domain Governance | 25 | MEDIA_DOMAIN_GOVERNANCE.md, MINT_PRODUCT_GOVERNANCE.md |
| Infrastructure | 20 | INFRASTRUCTURE_AUTHORITY.md, SHOP_VM_ARCHITECTURE.md |
| Operations | 30 | BACKUP_GOVERNANCE.md, RELEASE_PROTOCOL.md, N8N_RECOVERY_RUNBOOK.md |
| Agent Contracts | 10 | AGENT_BOUNDARIES.md, TERMINAL_WORKER_RUNTIME_CONTRACT_V2.md |
| SSOT Documents | 15 | DEVICE_IDENTITY_SSOT.md, MACBOOK_SSOT.md, MINILAB_SSOT.md |
| Audit Reports | 10 | _audits/*.md |

### ops/agents/ (12 contracts)

| Contract | Status | Domain |
|----------|--------|--------|
| microsoft-agent.contract.md | active | microsoft |
| communications-agent.contract.md | active | communications |
| media-agent.contract.md | active | media |
| mint-agent.contract.md | active | mint |
| finance-agent.contract.md | active | finance |
| workbench-agent.contract.md | active | workbench |
| immich-agent.contract.md | active | immich |
| home-assistant-agent.contract.md | active | ha |
| n8n-agent.contract.md | active | n8n |
| firefly-agent.contract.md | planned | finance |
| paperless-agent.contract.md | planned | finance |
| mint-os-agent.contract.md | planned | mint |

### ops/bindings/ (Registries)

| Registry | Purpose | Entries |
|----------|---------|---------|
| gate.registry.yaml | Gate definitions | 242 |
| gate.execution.topology.yaml | Domain assignments | 19 domains |
| gate.domain.profiles.yaml | Domain profiles | 19+ |
| gate.agent.profiles.yaml | Agent profiles | 12+ |
| agents.registry.yaml | Agent registry | 12 |
| business.registry.yaml | Business entities | ~50 |
| domain.portfolio.registry.yaml | Domain portfolio | ~20 |
| platform.integration.registry.yaml | Integrations | ~30 |
| home.device.registry.yaml | Home devices | ~50 |
| registry.ownership.yaml | Ownership mappings | ~100 |

---

## Drift Classification

### Class 1: Contract Exists, Runtime Absent

| Contract | Expected Runtime | Status | Evidence |
|----------|------------------|--------|----------|
| firefly-agent.contract.md | firefly service | PLANNED | Contract exists, agent not active |
| paperless-agent.contract.md | paperless service | PLANNED | Contract exists, agent not active |
| mint-os-agent.contract.md | mint-os-agent | PLANNED | Contract exists, agent not active |

**Verdict:** ACCEPTABLE - These are planned future integrations

### Class 2: Runtime Exists, Contract Missing

| Runtime Component | Location | Gap |
|-------------------|----------|-----|
| (None identified) | - | - |

**Verdict:** GOOD - No orphaned runtime components

### Class 3: Duplicate Truth Sources

| Information | Source 1 | Source 2 | Conflict |
|-------------|----------|----------|----------|
| VM definitions | vm.lifecycle.yaml | vm.lifecycle.contract.yaml | Partial overlap |
| Service endpoints | services.health.yaml | Multiple domain contracts | Acceptable - different scopes |

**Recommendation:** Review vm.lifecycle.* files for consolidation opportunity

### Class 4: Stale Ownership / last_verified

| File | Last Verified | Days Old | Status |
|------|---------------|----------|--------|
| docs/governance/AGENT_GOVERNANCE_BRIEF.md | 2026-02-22 | 5 | FRESH |
| docs/governance/SESSION_PROTOCOL.md | Unknown | - | NEEDS VERIFICATION |
| Multiple SSOT files | Various | - | NEEDS AUDIT |

**Recommendation:** Add last_verified dates to all governance documents

### Class 5: Gate Blind Spots

| Domain | Gates | Coverage Gaps |
|--------|-------|---------------|
| media | D223-D232 | media playback reliability needs dedicated gate |
| md1400 | - | No dedicated MD1400 capacity gate |
| communications | D147, D160, D198-D208 | Good coverage |

**Recommendation:** Add MD1400 capacity monitoring gate

---

## Gate Registry Analysis

### Gate Distribution by Category

| Category | Count | Severity Mix |
|----------|-------|--------------|
| path-hygiene | 30+ | high/medium |
| git-hygiene | 15+ | high |
| ssot-hygiene | 20+ | medium |
| secrets-hygiene | 15+ | critical/high |
| doc-hygiene | 20+ | medium/low |
| loop-gap-hygiene | 20+ | medium |
| workbench-hygiene | 15+ | medium |
| infra-hygiene | 30+ | high/critical |
| agent-surface-hygiene | 10+ | medium |
| process-hygiene | 20+ | critical/medium |
| media-hygiene | 10+ | standard |
| retired | 1 | N/A |

### Core Gates (15 required for core mode)

- D3: entrypoint-smoke (critical)
- D63: secrets binding
- D67: secrets status
- D121: worktree hygiene
- D124: capability domain catalog
- D126: gate registry
- D127: domain assignment drift lock
- D148: quality gate
- D150: code-root hygiene
- D153: project attach parity
- D163-D167: workbench operator smoothness

---

## Capability Approval Analysis

### Manual Approval Required (113 capabilities)

**By Domain:**

| Domain | Manual Capabilities |
|--------|---------------------|
| infra | 25+ (maintenance, network changes) |
| home | 15+ (physical device control) |
| microsoft | 10+ (mail, calendar operations) |
| media | 10+ (download, streaming control) |
| finance | 10+ (transaction operations) |
| secrets | 5+ (credential operations) |
| governance | 10+ (gate modifications) |

### Auto Approval (remaining capabilities)

- Read-only status checks
- Health probes
- List/query operations
- Session management
- Receipt generation

---

## Workbench Alignment Audit

### Workbench Structure

```
~/code/workbench/
├── docs/
│   ├── brain-lessons/     # ~30 files
│   ├── infrastructure/    # ~20 files
│   └── receipts/          # ~5 files
├── scripts/
│   ├── agents/           # 10 files
│   ├── finance/          # 5 files
│   ├── infrastructure/   # 5 files
│   ├── modules-files-api/# 3 files
│   └── root/             # 66 files
├── .archive-immutable/   # Deprecated scripts
└── runtime/              # Runtime artifacts
```

### Undocumented Scripts

| Script | Location | Documentation |
|--------|----------|---------------|
| deploy/stack-map.sh | workbench/scripts/root/deploy/ | MISSING |
| cleanup-repositories.sh | workbench/scripts/infrastructure/ | PARTIAL |
| Multiple finance scripts | workbench/scripts/finance/ | PARTIAL |

### Duplicate Operational Paths

| Operation | Path 1 | Path 2 | Recommendation |
|-----------|--------|--------|----------------|
| Backup operations | workbench/docs/infrastructure/domains/backup/ | agentic-spine/ops/plugins/backup/ | Consolidate to spine |
| Service status | workbench/scripts/root/smoke-test.sh | agentic-spine capabilities | Consolidate to capabilities |

---

## Drift Matrix Summary

| Category | Total | Drift Found | Severity |
|----------|-------|-------------|----------|
| Agent Contracts | 12 | 3 (planned) | LOW |
| Gate Definitions | 242 | 0 | NONE |
| Capability Scripts | 577 | 0 | NONE |
| Governance Docs | 125 | ~20 stale dates | LOW |
| Workbench Scripts | ~100 | ~30 undocumented | MEDIUM |
| Duplicate Paths | 2 | 2 | LOW |

---

## Recommendations

### Immediate (24h)
1. Add last_verified dates to governance documents without them
2. Document root scripts in workbench/scripts/

### Weekend Upgrades
1. Consolidate backup operations to spine capabilities
2. Add MD1400 capacity monitoring gate
3. Review vm.lifecycle.* files for consolidation

### 2-Week Hardening
1. Establish governance doc freshness policy (90-day review cycle)
2. Create automated drift detection for contract/runtime parity
3. Implement capability coverage metrics per domain

---

## Attestation

**No Mutations Performed:** This audit was READ-ONLY only.
**Active Lanes Untouched:**
- LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
- GAP-OP-973
- Active EWS import activity
- Active MD1400 rsync activity

---

*Generated by W51 Foundational Forensic Audit*
