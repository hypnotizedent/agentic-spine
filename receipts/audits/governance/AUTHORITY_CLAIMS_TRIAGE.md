# Authority Claims Triage

> **Date:** 2026-01-25

---

## ✅ FINAL STATE

| Metric | Before | After |
|--------|--------|-------|
| Files claiming `status: authoritative` | 40 | 21 |
| Files registered in SSOT_REGISTRY.yaml | 18 | 27 |
| **Unregistered gap** | **22** | **0** |

**All authority claims now registered. Rule 12 in pre-commit prevents regression.**

---

## Historical Triage Data (Pre-Cleanup)

> **Initial claims:** 40 files
> **Initially registered:** 18
> **Initial gap:** 22 unregistered

## Registered (18) ✅ — No action needed

| Path | Scope | Priority |
|------|-------|----------|
| `docs/governance/SESSION_PROTOCOL.md` | session-entry | 1 |
| `docs/governance/DEVICE_IDENTITY_SSOT.md` | device-naming-identity | 1 |
| `docs/governance/GOVERNANCE_INDEX.md` | governance-guide | 4 |
| `docs/governance/RAG_INDEXING_RULES.md` | rag-quality | 3 |
| `docs/governance/REPO_STRUCTURE_AUTHORITY.md` | repository-structure | 1 |
| `docs/governance/SEARCH_EXCLUSIONS.md` | search-indexing | 3 |
| `docs/governance/SECRETS_POLICY.md` | secrets-management | 2 |
| `docs/runbooks/BACKUP_GOVERNANCE.md` | backup-strategy | 2 |
| `docs/runbooks/REBOOT_HEALTH_GATE.md` | reboot-validation | 2 |
| Workbench service registry | services-topology | 1 |
| Workbench authority index (external) | document-registry | 4 |
| Workbench incidents log (external) | incident-history | 2 |
| Workbench SSOT index (external) | ssot-index | 4 |
| `infrastructure/shopify-mcp/SHOPIFY_SSOT.md` | shopify-integration | 2 |
| `mint-os/docs/QUOTE_SINGLE_SOURCE_OF_TRUTH.md` | quote-creation | 2 |
| `mint-os/docs/SCHEMA_TRUTH.md` | database-schema | 1 |
| `mint-os/docs/modules/files/SPEC.md` | files-minio | 2 |
| Workbench RAG manifest (external) | rag-config | 3 |

---

## Unregistered (22) — Triage Required

### 🔻 DOWNGRADE to `status: reference` (13)

These are indexes, inventories, or reference docs — not policy.

| Path | Current | Reason | Action |
|------|---------|--------|--------|
| `home-assistant/docs/reference/REF_AUTOMATIONS.md` | authoritative | inventory, not policy | → `status: reference` |
| `home-assistant/docs/reference/REF_INTEGRATIONS.md` | authoritative | inventory, not policy | → `status: reference` |
| `home-assistant/docs/reference/REF_BUTTONS.md` | authoritative | inventory, not policy | → `status: reference` |
| `home-assistant/docs/reference/REF_HELPERS.md` | authoritative | inventory, not policy | → `status: reference` |
| `home-assistant/docs/reference/REF_UNAVAILABLE.md` | authoritative | inventory, not policy | → `status: reference` |
| `home-assistant/docs/reference/REF_ENTITY_DOMAINS.md` | authoritative | inventory, not policy | → `status: reference` |
| `mint-os/docs/reference/INDEX.md` | authoritative | index, not policy | → `status: reference` |
| `mint-os/docs/modules/shipping/INDEX.md` | authoritative | index, not policy | → `status: reference` |
| `mint-os/docs/modules/files/INDEX.md` | authoritative | index, not policy | → `status: reference` |
| `mint-os/docs/modules/pricing/INDEX.md` | authoritative | index, not policy | → `status: reference` |
| `mint-os/docs/modules/suppliers/INDEX.md` | authoritative | index, not policy | → `status: reference` |
| `mint-os/docs/modules/files/PHASE_MAP.md` | authoritative | snapshot/plan, not policy | → `status: reference` |
| `mint-os/docs/plans/ARTWORK_MASTER_PLAN.md` | authoritative | plan, not policy | → `status: plan` |

### ✅ REGISTER as SSOT (6)

These define real policy/constraints that agents/people must follow.

| Path | Scope | Priority | Notes |
|------|-------|----------|-------|
| `docs/governance/SCRIPTS_AUTHORITY.md` | scripts-placement | 2 | Rules for where scripts go |
| `docs/governance/ISSUE_CLOSURE_SOP.md` | issue-workflow | 3 | SOP is policy |
| `docs/governance/AGENT_BOUNDARIES.md` | agent-rules | 2 | Defines agent constraints |
| `docs/governance/SPEC_REQUIRED_SOP.md` | spec-workflow | 3 | SOP is policy |
| Workbench MCP authority (external) | mcp-servers | 2 | Rules for MCP servers |
| `mint-os/docs/modules/shipping/SPEC.md` | shipping-module | 2 | SPEC is policy |

### ⚠️ NEEDS REVIEW (3)

Read content before deciding.

| Path | Question |
|------|----------|
| `infrastructure/RAG_ARCHITECTURE.md` | Is this policy or architecture snapshot? |
| Workbench docs module spec (external) | Is this active or legacy? |
| Workbench homelab module spec (external) | Is this active or legacy? |
| Workbench agent context pack (external) | Is this policy or just a bundle? |
| Workbench incident runbook (external) | Is this active or superseded by incidents log? |
| `mint-os/INFRASTRUCTURE_MAP.md` | Is this a snapshot or does it define rules? |
| `docs/governance/INFRASTRUCTURE_AUTHORITY.md` | What's its scope vs SERVICE_REGISTRY? |
| `mint-os/docs/architecture/FILE_ARCHITECTURE_GOVERNANCE.md` | Overlaps with files/SPEC.md? |
| `mint-os/docs/modules/suppliers/SPEC.md` | Is this active? |

---

## Execution Script

```bash
# DOWNGRADE: Change "status: authoritative" → "status: reference" in these 13 files
FILES_TO_DOWNGRADE=(
  "home-assistant/docs/reference/REF_AUTOMATIONS.md"
  "home-assistant/docs/reference/REF_INTEGRATIONS.md"
  "home-assistant/docs/reference/REF_BUTTONS.md"
  "home-assistant/docs/reference/REF_HELPERS.md"
  "home-assistant/docs/reference/REF_UNAVAILABLE.md"
  "home-assistant/docs/reference/REF_ENTITY_DOMAINS.md"
  "mint-os/docs/reference/INDEX.md"
  "mint-os/docs/modules/shipping/INDEX.md"
  "mint-os/docs/modules/files/INDEX.md"
  "mint-os/docs/modules/pricing/INDEX.md"
  "mint-os/docs/modules/suppliers/INDEX.md"
  "mint-os/docs/modules/files/PHASE_MAP.md"
)

for f in "${FILES_TO_DOWNGRADE[@]}"; do
  sed -i 's/status: authoritative/status: reference/' "$f"
done

# Special case
sed -i 's/status: authoritative/status: plan/' "mint-os/docs/plans/ARTWORK_MASTER_PLAN.md"
```

---

## Definition of Done

- [ ] All 13 downgrades applied
- [ ] All 6 registrations added to SSOT_REGISTRY.yaml
- [ ] 9 "needs review" files triaged
- [ ] `rg "status:\s*authoritative"` matches registry exactly
- [ ] Pre-commit guard added
