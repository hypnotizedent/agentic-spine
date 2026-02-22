# L1 Baseline Surfaces Audit

> **Audit ID:** WORKBENCH-AOF-NORMALIZATION-INBOX-20260216
> **Lane:** A (baseline surfaces)
> **Scope:** Workbench baseline/doc surfaces normalization
> **Date:** 2026-02-16
> **Status:** Read-only audit lane (no fixes)

---

## Summary

| Severity | Count | Category |
|----------|-------|----------|
| P0 | 1 | Timestamp metadata field naming |
| P1 | 4 | Frontmatter, loop linkage, inventory metadata |
| P2 | 2 | Terminal naming, legacy doc format |

**Total findings:** 7

---

## P0 Findings

### [P0] Timestamp Field Naming Inconsistency

- **Surface:** baseline/docs (markdown + yaml)
- **Problem:** Multiple timestamp field names used across workbench surfaces without alignment to spine canonical naming.
- **Impact:** D58 enforcement cannot reliably check freshness; automated tools cannot parse timestamps consistently.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:7 — uses `last_snapshot`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:20,67,92,102,111,121,130 — uses `snapshot_date` (6 occurrences)
  - /Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_MCP_INTEGRATION.md:4 — uses `last_reviewed`
  - /Users/ronnyworks/code/workbench/docs/brain-lessons/*.md — uses `last_verified` (majority)
  - /Users/ronnyworks/code/workbench/dotfiles/opencode/commands/*.md — uses `last_verified` (all 10 command files)
- **Canonical rule (expected):**
  - Spine uses `last_verified` for markdown frontmatter (see `/Users/ronnyworks/code/agentic-spine/docs/governance/SSOT_REGISTRY.yaml` and all governance docs).
  - Spine uses `last_reviewed` for SSOT registry entries within YAML files.
  - `snapshot_date` and `last_snapshot` are non-canonical and should migrate to `last_verified`.
- **Recommended normalization:**
  1. Standardize all markdown files to use `last_verified` in YAML frontmatter.
  2. Standardize all YAML inventory files to use `last_verified` for document-level metadata.
  3. Migrate `snapshot_date` → `last_verified` in CONTAINER_INVENTORY.yaml.
  4. Migrate `last_snapshot` → `last_verified` in CONTAINER_INVENTORY.yaml metadata block.
  5. Keep `last_reviewed` only for entries within SSOT_REGISTRY.yaml-style registries.

---

## P1 Findings

### [P1] Frontmatter Format Inconsistency

- **Surface:** baseline/docs (markdown)
- **Problem:** Mixed use of YAML frontmatter (`---` blocks) vs inline metadata format (`> **Status:** ...`).
- **Impact:** Automated linting cannot validate metadata consistently; doc indexers may miss inline metadata.
- **Evidence:**
  - 201 files use YAML frontmatter (`---` delimiter)
  - 43 files use inline `> **Status:**` format
  - Examples of inline format:
    - /Users/ronnyworks/code/workbench/docs/infrastructure/AUTHORITY_INDEX.md:11 — `> **Status: reference (non-authoritative)**`
    - /Users/ronnyworks/code/workbench/docs/brain-lessons/MEDIA_DOWNLOAD_ARCHITECTURE.md:3 — `> **Status:** authoritative`
    - /Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/LEGACY_TIES.md:9 — `> **Status:** reference`
- **Canonical rule (expected):**
  - All governed documents must use YAML frontmatter with canonical fields: `status`, `owner`, `last_verified`, `scope`.
  - Inline metadata format is deprecated but tolerated for legacy/archive content.
- **Recommended normalization:**
  1. Convert all non-legacy docs (under `docs/infrastructure/`, `docs/brain-lessons/`, `agents/*/docs/`) to YAML frontmatter.
  2. Keep inline format only for `docs/legacy/` content (explicitly excluded by D16/D17).
  3. Add lint rule to enforce frontmatter for non-legacy paths.

### [P1] Loop Linkage Field Inconsistency

- **Surface:** baseline/docs (markdown + yaml)
- **Problem:** Multiple field names used to link documents to parent loops.
- **Impact:** Tooling cannot reliably extract loop context; cross-references break.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_LEGACY_EXTRACTION_MATRIX.md:7 — uses `parent_loop`
  - /Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_LEGACY_EXTRACTION_MATRIX.md:8 — uses `active_loop`
  - /Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_PILLAR_EXTRACTION_STATUS.md:6 — uses `loop_id`
  - /Users/ronnyworks/code/workbench/docs/brain-lessons/FINANCE_RECONCILIATION.md:6 — uses `loop_id`
  - /Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_OPERATIONAL_RUNBOOK.md:6 — uses `parent_loop`
  - /Users/ronnyworks/code/workbench/docs/brain-lessons/IMMICH_BACKUP_RESTORE.md:7 — uses `parent_loop`
- **Canonical rule (expected):**
  - Use `parent_loop` for documents that are evidence/artifacts of a parent loop.
  - Use `discovered_by` for gaps/audits that were found during loop work.
  - Do NOT use `loop_id` or `active_loop` as frontmatter fields.
- **Recommended normalization:**
  1. Migrate all `loop_id` → `parent_loop` in frontmatter.
  2. Remove `active_loop` field; if a doc tracks active status, use `status: active|complete|archived`.
  3. Add frontmatter schema validation to catch non-canonical loop fields.

### [P1] MCP_INVENTORY.yaml Missing Canonical Metadata Header

- **Surface:** baseline/inventory (yaml)
- **Problem:** MCP_INVENTORY.yaml lacks YAML frontmatter with canonical governance fields.
- **Impact:** Document cannot be freshness-checked by D58; ownership unclear.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/infra/data/MCP_INVENTORY.yaml:1-9 — has comment header but no `---` frontmatter block
  - Missing fields: `status`, `owner`, `last_verified`, `scope`
- **Canonical rule (expected):**
  - All YAML inventory files must have frontmatter block with canonical fields.
  - See spine's /Users/ronnyworks/code/agentic-spine/docs/governance/SSOT_REGISTRY.yaml:1-15 for pattern.
- **Recommended normalization:**
  1. Add frontmatter block:
     ```yaml
     ---
     status: authoritative
     owner: "@ronny"
     last_verified: <date>
     scope: mcp-inventory
     ---
     ```
  2. Add `last_verified` field and keep it updated on each inventory change.

### [P1] CONTAINER_INVENTORY.yaml VMID Field Placement

- **Surface:** baseline/inventory (yaml)
- **Problem:** `vmid:` field appears at nested host level instead of following standardized metadata placement.
- **Impact:** Inconsistent with spine vm.lifecycle.binding pattern; automation may miss VM identity.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:63 — `vmid: 207` nested under `hosts.ai-consolidation`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:88 — `vmid: 200` nested under `hosts.docker-host`
  - 6 total occurrences at lines 63, 88, 98, 107, 117, 126
- **Canonical rule (expected):**
  - VM identity fields should align with spine's `ops/bindings/vm.lifecycle.yaml` schema.
  - Field name should be `vm_id` (snake_case) for consistency with other bindings.
- **Recommended normalization:**
  1. Evaluate whether CONTAINER_INVENTORY.yaml should reference spine's vm.lifecycle.binding instead of duplicating vmid.
  2. If keeping local, rename `vmid` → `vm_id` for consistency.
  3. Add cross-reference to canonical VM SSOT in spine.

---

## P2 Findings

### [P2] Terminal Name References Not Aligned With Canonical Contract

- **Surface:** baseline/docs (markdown)
- **Problem:** Terminal name references in workbench docs use informal names not aligned with canonical terminal.role.contract.yaml.
- **Impact:** Runbook references may become stale; D135 enforcement cannot validate terminal naming.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/dotfiles/macbook/README.md:77 — references `SPINE-CONTROL-01` (correct)
  - /Users/ronnyworks/code/workbench/dotfiles/macbook/README.md:79 — references `SPINE-AUDIT-01` (correct)
  - /Users/ronnyworks/code/workbench/dotfiles/macbook/README.md:81 — references `DOMAIN-HA-01` (correct)
  - /Users/ronnyworks/code/workbench/agents/home-assistant/docs/RUNBOOK.md:11 — references `DOMAIN-HA-01` (correct)
- **Canonical rule (expected):**
  - All terminal names must match entries in /Users/ronnyworks/code/agentic-spine/ops/bindings/terminal.role.contract.yaml.
  - Pattern: `^[A-Z]+-[A-Z0-9]+-[0-9]{2}$`
- **Recommended normalization:**
  1. Verify all terminal references match contract entries.
  2. Add terminal role contract reference to workbench AGENTS.md.
  3. Consider adding lint rule to validate terminal names against contract.

### [P2] Legacy Docs Using Inline Metadata Format

- **Surface:** baseline/docs (legacy)
- **Problem:** Legacy docs under `docs/legacy/` use inline `> **Status:**` format instead of YAML frontmatter.
- **Impact:** Lower priority since D16/D17 exclude legacy content from active governance.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/LEGACY_TIES.md:9 — `> **Status:** reference`
  - /Users/ronnyworks/code/workbench/docs/legacy/infrastructure/reference/README.md:11 — `> **Status:** Living document...`
  - Multiple files under `docs/legacy/infrastructure/` use inline format
- **Canonical rule (expected):**
  - Legacy content is exempt from frontmatter requirements (D16/D17).
  - Inline format is acceptable for archive-only content.
- **Recommended normalization:**
  1. No action required for true legacy/archive content.
  2. If any legacy docs are actively referenced, migrate to frontmatter and move out of legacy/.

---

## Coverage Checklist

- [x] Entry docs parity (README, AGENTS/CLAUDE equivalents, runbooks)
- [x] Domain catalog consistency
- [x] Folder ownership boundaries (control-plane vs domain assets)
- [x] Naming conventions (ids, status, date keys)

---

## Audit Scope

- **Files scanned:**
  - Markdown files: ~244 total (201 with frontmatter, 43 with inline format)
  - YAML files: ~15 inventory/config files
  - Governance references: 164 matches across workbench surfaces
- **Patterns searched:**
  - `spine.verify|verify.core.run|verify.domain.run|mailroom|proposal|terminal-name|SPINE-`
  - `vmid|vm_id|id|notes|description|status|lifecycle|opened|created_at|updated|last_verified`
  - `parent_loop|loop_id|active_loop|LOOP-`
  - Frontmatter and inline metadata formats

---

## Next Steps

1. **P0:** Prioritize timestamp field normalization for D58 compatibility.
2. **P1:** Convert non-legacy docs to YAML frontmatter format.
3. **P1:** Standardize loop linkage fields across all extraction matrices.
4. **P2:** Verify terminal name references against terminal.role.contract.yaml.

---

**Lane A COMPLETE.**
