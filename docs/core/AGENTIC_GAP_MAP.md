# AGENTIC_GAP_MAP

> **Status:** authoritative
> **Last verified:** 2026-02-04

> **Purpose:** Track what has been extracted from the workbench monolith into the spine,
> what hasn't, and what's left to do. Agents use this to understand
> coverage without needing to read `~/Code/workbench`.

---

## Extraction Status: Workbench SSOT → Spine

> All workbench paths below are under `~/Code/workbench/`.

| Workbench SSOT | Spine Equivalent | Status |
|----------------|-------------------|--------|
| `infrastructure/SERVICE_REGISTRY.md` | `docs/governance/STACK_REGISTRY.yaml` | EXTRACTED (partial — stack inventory only) |
| `infrastructure/docs/AUTHORITY_INDEX.md` | `docs/governance/GOVERNANCE_INDEX.md` | EXTRACTED (surgical — spine-scoped subset) |
| `infrastructure/docs/AGENT_CONTEXT_PACK.md` | `docs/core/CORE_LOCK.md` + `CAPABILITIES_OVERVIEW.md` | EXTRACTED |
| `.github/labels.yml` | `.github/labels.yml` | EXTRACTED |
| `infrastructure/docs/hardware/HARDWARE_REGISTRY.md` | `docs/core/DEVICE_IDENTITY_SSOT.md` | EXTRACTED (identity only, not full hardware) |
| `docs/governance/SSOT_REGISTRY.yaml` | Not extracted | NOT EXTRACTED |
| `docs/governance/REPO_STRUCTURE_AUTHORITY.md` | Not extracted | NOT EXTRACTED |
| `docs/governance/COMPOSE_AUTHORITY.md` | `docs/governance/STACK_REGISTRY.yaml` (partial) | PARTIAL |
| `docs/governance/PORTABILITY_ASSUMPTIONS.md` | Not extracted | NOT EXTRACTED |
| `docs/governance/AGENT_BOUNDARIES.md` | `docs/core/CAPABILITIES_OVERVIEW.md` (partial) | PARTIAL |
| `docs/governance/ISSUE_CLOSURE_SOP.md` | Not extracted | NOT EXTRACTED |
| `mint-os/INFRASTRUCTURE_MAP.md` | Not extracted (schema/DB details) | NOT EXTRACTED |
| `infrastructure/docs/INCIDENTS_LOG.md` | Not extracted | NOT EXTRACTED |
| `infrastructure/data/agents_inventory.json` | Not extracted | NOT EXTRACTED (see below) |
| `infrastructure/data/updates_inventory.json` | Not extracted | NOT EXTRACTED |

---

## Agent Scripts Inventory

The workbench contains ~35 agent scripts in `scripts/agents/`. Most are legacy
one-off automation that predates the spine capability model.

**Categories:**

| Category | Count | Spine Status |
|----------|-------|-------------|
| Audit/verify scripts | ~10 | Replaced by drift gates (D1–D24) |
| Docker management | ~5 | Replaced by `docker.compose.status` capability |
| RAG/indexing | ~4 | Not applicable to spine (workbench-specific) |
| Secrets management | ~3 | Replaced by `secrets.*` capabilities |
| Git/GitHub utilities | ~3 | Replaced by `github.*` capabilities |
| Deploy scripts | ~4 | Not extracted (deploy is out of spine scope) |
| Misc utilities | ~6 | Legacy — no extraction planned |

**Key insight:** The spine does not need to extract agent scripts 1:1.
The capability model (`ops/capabilities.yaml`) replaces the script-per-task
pattern with governed, receipt-producing capabilities.

---

## What's Left to Extract

### High Priority (blocks spine self-containment)

1. **SSOT_REGISTRY.yaml** — The spine needs its own SSOT registry rather than
   pointing back to the workbench. Currently, governance docs reference workbench
   registry patterns.

2. **COMPOSE_AUTHORITY completion** — STACK_REGISTRY.yaml has compose paths
   but doesn't carry the authority rules from COMPOSE_AUTHORITY.md.

### Medium Priority (useful but not blocking)

3. **PORTABILITY_ASSUMPTIONS** — Environment coupling documentation. The spine
   currently assumes paths without documenting them.

4. **INCIDENTS_LOG** — Historical incident context. Could be a spine-scoped
   subset for infrastructure incidents that affect spine operations.

5. **AGENT_BOUNDARIES completion** — CAPABILITIES_OVERVIEW covers what agents
   can do but doesn't fully replicate the boundary constraints from the workbench.

### Low Priority (defer or skip)

6. **ISSUE_CLOSURE_SOP** — Process doc. The spine follows GitHub issue workflow
   naturally; a separate SOP may not be needed.

7. **Schema/DB details** (INFRASTRUCTURE_MAP) — Spine doesn't manage databases
   directly. Only relevant if spine capabilities need schema awareness.

8. **GOVERNANCE_INDEX.md full rewrite** — Currently contains deep workbench
   references. Surgical edits done; full spine-native rewrite tracked here.

---

## Infrastructure Pillar: ronny-ops → Workbench

> **Purpose:** Track extraction of infrastructure assets from `~/ronny-ops/infrastructure/`
> into `~/Code/workbench/` so agents work entirely from `/Code`.
>
> **Capability:** `ops cap run infra.extraction.status` (receipt-producing, 23 asset groups)
> **Docs check:** `ops cap run docs.status` (verifies file counts per directory)

| # | Asset Group | Source (ronny-ops) | Target (workbench) | Min Files | Status |
|---|-------------|-------------------|-------------------|-----------|--------|
| 1 | runbooks | `docs/runbooks/` | `docs/infrastructure/runbooks/` | 30 | EXTRACTED |
| 2 | reference | `docs/reference/` | `docs/infrastructure/reference/` | 16 | EXTRACTED |
| 3 | locations | `docs/locations/` | `docs/infrastructure/locations/` | 3 | EXTRACTED |
| 4 | hardware | `docs/hardware/` | `docs/infrastructure/hardware/` | 2 | EXTRACTED |
| 5 | architecture | `docs/architecture/` | `docs/infrastructure/architecture/` | 4 | EXTRACTED |
| 6 | audits | `audits/` + `docs/audits/` | `docs/infrastructure/audits/` | 5 | EXTRACTED |
| 7 | cloudflare-docs | `cloudflare/` + `docs/cloudflare/` | `docs/infrastructure/cloudflare/` | 3 | EXTRACTED |
| 8 | domains | `domains/` | `docs/infrastructure/domains/` | 2 | EXTRACTED |
| 9 | guides | `docs/guides/` | `docs/infrastructure/guides/` | 6 | EXTRACTED |
| 10 | homelab | `docs/homelab/` | `docs/infrastructure/homelab/` | 3 | EXTRACTED |
| 11 | rag-docs | `docs/rag/` | `docs/infrastructure/rag/` | 6 | EXTRACTED |
| 12 | secrets-docs | `docs/secrets/` | `docs/infrastructure/secrets/` | 2 | EXTRACTED |
| 13 | authority-docs | top-level `*.md` + `*.yaml` | `docs/infrastructure/` (top-level) | 18 | EXTRACTED |
| 14 | mcp-docs | `mcpjungle/docs/` + `RECOVERY_RUNBOOK` | `docs/infrastructure/mcp/` | 3 | EXTRACTED |
| 15 | microsoft-docs | `microsoft/` | `docs/infrastructure/microsoft/` | 2 | EXTRACTED |
| 16 | n8n-docs | `n8n/*.md` + `n8n/runbooks/` | `docs/infrastructure/n8n/` | 3 | EXTRACTED |
| 17 | compose-stacks | `mcpjungle/`, `n8n/`, `dashy/`, etc. | `infra/compose/` | 8 | EXTRACTED |
| 18 | n8n-workflows | `n8n/workflows/` | `infra/compose/n8n/workflows/` | 30 | EXTRACTED |
| 19 | mcpjungle | `mcpjungle/` (compose + servers) | `infra/compose/mcpjungle/` | 10 | EXTRACTED |
| 20 | data-inventories | `data/` | `infra/data/` | 6 | EXTRACTED |
| 21 | templates | `templates/` | `infra/templates/` | 5 | EXTRACTED |
| 22 | cloudflare-ops | `cloudflare/` (tunnel + exports) | `infra/cloudflare/` | 3 | EXTRACTED |
| 23 | dotfiles-ssh | `dotfiles/ssh/` | `dotfiles/ssh/` | 3 | EXTRACTED |

**Coverage formula:** `(EXTRACTED + 0.5 * PARTIAL) / 23 * 100`

| Metric | Value |
|--------|-------|
| Extracted | 23 |
| Partial | 0 |
| Not Extracted | 0 |
| Coverage | **100.0%** |
| Extraction date | 2026-02-04 |

**Excluded (by design):** `secrets/docker-compose.yml`, live `.env` files, `n8n-credentials.sh`,
`CURRENT_STATE.md`, `docs/TODAY.md`, `docs/sessions/`, `docs/evidence/`,
`mint-os-vault/migrations/`, `shopify-mcp/migrations/`, `skills/`, `docs/prompts/`, `docs/knowledge/`

---

## SSOT Registry Cleanup (2026-02-04)

### 8 Entries Archived (ronny-ops/workbench-scoped)

These entries were removed from `docs/governance/SSOT_REGISTRY.yaml` because they
reference workbench-specific artifacts, not spine governance. Each removal is
documented in the registry's `REMOVED ENTRIES` comment section.

| Removed Entry | Reason |
|---------------|--------|
| `quote-intake-slimming-proposal` | Proposal doc; mint-os specific |
| `artwork-ticket-model` | Module spec; workbench-scoped |
| `minio-rclone-setup` | Setup guide; workbench-scoped |
| `artwork-module.release_gate` | Release gate; workbench-scoped |
| `infisical-restructure` | One-time migration plan; stale |
| `mint-files-integration` | Integration matrix; workbench-scoped |
| `spine-standard-route` | Navigation entry; replaced by `docs/README.md` |
| `spec-required-sop` | Meta-SOP; covered by `CONTRIBUTING.md` + `docs.lint` |

### 6 New Spine-Native Governance Docs

These files were created to satisfy existing SSOT registry entries that previously
pointed to nonexistent paths:

| New Doc | SSOT ID | Purpose |
|---------|---------|---------|
| `docs/governance/ISSUE_CLOSURE_SOP.md` | `issue-closure-sop` | Issue closure checklist |
| `docs/governance/RAG_INDEXING_RULES.md` | `rag-indexing-rules` | RAG quality gate |
| `docs/governance/SEARCH_EXCLUSIONS.md` | `search-exclusions` | Search exclusion patterns |
| `docs/governance/SECRETS_POLICY.md` | `secrets-policy` | Secrets management rules |
| `docs/governance/BACKUP_GOVERNANCE.md` | `backup-governance` | Backup strategy and verification |
| `docs/governance/REBOOT_HEALTH_GATE.md` | `reboot-health-gate` | Safe reboot procedures |

---

## Cross-References

| Document | Relationship |
|----------|--------------|
| `docs/core/EXTRACTION_PROTOCOL.md` | How extractions are done |
| `docs/governance/STACK_REGISTRY.yaml` | Primary extraction target for stack data |
| `docs/core/CAPABILITIES_OVERVIEW.md` | What capabilities replace legacy scripts |
| `docs/governance/GOVERNANCE_INDEX.md` | Governance entry point (partial extraction) |
