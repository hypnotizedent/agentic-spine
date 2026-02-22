# L1 Baseline Surfaces Audit (Lane A)

> **Audit ID:** WORKBENCH-AOF-NORMALIZATION-INBOX-20260216  
> **Lane:** A (baseline surfaces)  
> **Scope:** Workbench baseline/doc surfaces normalization  
> **Date:** 2026-02-17  
> **Status:** Read-only audit lane (no fixes)

---

## Summary

| Severity | Count | Category |
|----------|-------|----------|
| P0 | 1 | Disallowed field `vmid` per spine.schema.conventions.yaml |
| P1 | 3 | Non-canonical status values, missing frontmatter, timestamp field drift |
| P2 | 1 | LOOP linkage field inconsistency |

**Total findings:** 5

---

## P0 Findings

### [P0] vmid Field Violates Schema Conventions

- **Surface:** baseline/inventory (yaml)
- **Problem:** Workbench YAML files use `vmid:` field which is explicitly disallowed by spine.schema.conventions.yaml D73-78.
- **Impact:** Schema validation will fail on touch; automation expects canonical `id` field for VM identity.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:63 — `vmid: 207`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:88 — `vmid: 200`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:98 — `vmid: 201`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:107 — `vmid: 202`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:117 — `vmid: 203`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:126 — `vmid: 102`
- **Canonical rule (expected):**
  - spine.schema.conventions.yaml:71-78 defines `canonical_id_field: id` and `disallowed_alias_keys: [vmid, notes, discovered_at, opened]`
  - VM entries should use `id:` not `vmid:`
- **Recommended normalization:**
  1. Rename all `vmid:` → `id:` in CONTAINER_INVENTORY.yaml
  2. Cross-reference spine's vm.lifecycle.yaml for canonical VM identity
  3. Consider whether CONTAINER_INVENTORY.yaml should reference spine binding instead of duplicating

---

## P1 Findings

### [P1] Non-Canonical Status Values in Inventory Files

- **Surface:** baseline/inventory (yaml)
- **Problem:** CONTAINER_INVENTORY.yaml uses Docker container status values (`up`, `created`, `dead`) which are not in spine.schema.conventions.yaml allowed_values list.
- **Impact:** Status field semantic drift; automated tooling cannot map to lifecycle states.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:25 — `status: "up"`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:33 — `status: "up"`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:41 — `status: "created"`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:48 — `status: "dead"`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:73 — `status: "up"`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:80 — `status: "up"`
- **Canonical rule (expected):**
  - spine.schema.conventions.yaml:21-49 defines allowed_values: `active, running, stopped, failed, done, etc.`
  - Docker statuses should map: `up` → `running`, `created` → `provisioned`, `dead` → `failed`
- **Recommended normalization:**
  1. Create explicit mapping comment in CONTAINER_INVENTORY.yaml header
  2. Consider using canonical values with `docker_status` field for raw output
  3. Alternative: add `container_status` field for Docker-native values, reserve `status` for governance

### [P1] MCP_INVENTORY.yaml Missing Canonical Frontmatter

- **Surface:** baseline/inventory (yaml)
- **Problem:** MCP_INVENTORY.yaml lacks YAML document frontmatter with canonical governance fields required by D58 freshness checks.
- **Impact:** Document cannot be freshness-validated; ownership and scope unclear to automation.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/infra/data/MCP_INVENTORY.yaml:1-14 — has comment header only, no `---` frontmatter
  - Missing: `status`, `owner`, `last_verified`, `scope`
- **Canonical rule (expected):**
  - All governed YAML files require frontmatter per spine.schema.conventions.yaml
  - Pattern: `---\nstatus: authoritative\nowner: "@ronny"\nlast_verified: YYYY-MM-DD\nscope: <name>\n---`
- **Recommended normalization:**
  1. Add frontmatter block with canonical fields
  2. Set `last_verified` to current date and maintain on edits
  3. Add `scope: mcp-inventory` for discovery

### [P1] Timestamp Field Drift from Canonical Naming

- **Surface:** baseline/docs (markdown + yaml)
- **Problem:** Multiple timestamp field variants used across workbench surfaces; inconsistent with spine's `last_verified` canonical.
- **Impact:** D58 freshness validation cannot reliably check all documents; automated scanners miss non-canonical fields.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:7 — `last_snapshot: "2026-02-09"`
  - /Users/ronnyworks/code/workbench/infra/data/CONTAINER_INVENTORY.yaml:20,67,92,102,111,121,130 — `snapshot_date:` (6 occurrences)
  - /Users/ronnyworks/code/workbench/docs/brain-lessons/*.md — uses `last_verified:` (correct, ~15 files)
  - /Users/ronnyworks/code/workbench/dotfiles/opencode/commands/*.md — uses `last_verified:` (correct, 10 files)
  - /Users/ronnyworks/code/workbench/docs/legacy/infrastructure/** — uses `last_verified:` (legacy, acceptable)
- **Canonical rule (expected):**
  - spine.schema.conventions.yaml:56-68 defines `canonical_fields: [created_at, updated_at, closed_at]` and `accepted_legacy_fields: [updated, last_verified, last_reviewed, last_synced, discovered_at, opened]`
  - `last_verified` is accepted for document freshness tracking
  - `last_snapshot` and `snapshot_date` are non-canonical
- **Recommended normalization:**
  1. Migrate `last_snapshot` → `last_verified` in CONTAINER_INVENTORY.yaml metadata
  2. Keep `snapshot_date` only if semantically different (per-host snapshot time) with comment explaining usage
  3. Standardize all markdown docs to use `last_verified` in frontmatter

---

## P2 Findings

### [P2] Loop Linkage Field Inconsistency

- **Surface:** baseline/docs (markdown)
- **Problem:** Multiple field names used to link documents to parent loops without canonical pattern.
- **Impact:** Tooling cannot reliably extract loop context; cross-references inconsistent.
- **Evidence:**
  - /Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_LEGACY_EXTRACTION_MATRIX.md:7 — `parent_loop: LOOP-SPINE-CONSOLIDATION-20260210`
  - /Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_LEGACY_EXTRACTION_MATRIX.md:8 — `active_loop:` (non-canonical)
  - /Users/ronnyworks/code/workbench/agents/finance/docs/FINANCE_PILLAR_EXTRACTION_STATUS.md:6 — `loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211`
  - /Users/ronnyworks/code/workbench/agents/home-assistant/docs/HASS_OPERATIONAL_RUNBOOK.md:6 — `parent_loop: LOOP-HASS-SSOT-AUTOGRADE-20260210`
  - /Users/ronnyworks/code/workbench/docs/brain-lessons/IMMICH_BACKUP_RESTORE.md:7 — `parent_loop: LOOP-IMMICH-LEGACY-EXTRACTION-20260211`
- **Canonical rule (expected):**
  - Use `parent_loop` for documents that are artifacts/evidence of a loop
  - Use `discovered_by` for gaps found during loop work
  - `loop_id` and `active_loop` are non-canonical
- **Recommended normalization:**
  1. Migrate all `loop_id` → `parent_loop`
  2. Remove `active_loop` field (use `status:` for lifecycle state)
  3. Document loop linkage convention in workbench AGENTS.md

---

## Coverage Checklist

- [x] Entry docs parity (README, AGENTS.md equivalents)
- [x] Domain catalog consistency
- [x] Folder ownership boundaries (control-plane vs domain)
- [x] Naming conventions (id, status, date keys per spine.schema.conventions.yaml)
- [x] Frontmatter format compliance

---

## Audit Scope

**Files scanned:**
- Markdown files: ~244 total
- YAML files: ~15 inventory/config files
- Governance patterns: 164 matches (spine.verify, mailroom, proposal, LOOP-)

**Patterns searched:**
- `spine.verify|verify.core.run|verify.domain.run|mailroom|proposal|SPINE-`
- `vmid|vm_id|id|notes|description|status|last_verified|last_snapshot|snapshot_date`
- `parent_loop|loop_id|active_loop|LOOP-`
- Frontmatter vs inline metadata format

**Canonical references:**
- /Users/ronnyworks/code/agentic-spine/ops/bindings/spine.schema.conventions.yaml
- /Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml
- /Users/ronnyworks/code/agentic-spine/ops/bindings/terminal.role.contract.yaml

---

## Next Steps

1. **P0:** Rename `vmid` → `id` in CONTAINER_INVENTORY.yaml (blocking schema validation)
2. **P1:** Add canonical frontmatter to MCP_INVENTORY.yaml
3. **P1:** Normalize status values with mapping comment
4. **P1:** Migrate timestamp fields to `last_verified`
5. **P2:** Standardize loop linkage to `parent_loop`

---

**LANE A COMPLETE.**
