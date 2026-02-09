# AGENTIC_GAP_MAP

> **Status:** authoritative
> **Last verified:** 2026-02-09

> **Purpose:** Track what has been extracted from the workbench monolith into the spine,
> what hasn't, and what's left to do. Agents use this to understand
> coverage without needing to browse external workbench docs.

---

## Extraction Status: Workbench SSOT → Spine

> All workbench references below are external and read-only. Consult
> `docs/governance/WORKBENCH_TOOLING_INDEX.md` for allowed tooling paths.

| Workbench SSOT (external) | Spine Equivalent | Status |
|---------------------------|------------------|--------|
| Workbench service registry | `docs/governance/SERVICE_REGISTRY.yaml` | EXTRACTED |
| Workbench authority index | `docs/governance/GOVERNANCE_INDEX.md` | EXTRACTED (surgical — spine-scoped subset) |
| Workbench agent context pack | `docs/core/CORE_LOCK.md` + `CAPABILITIES_OVERVIEW.md` | EXTRACTED |
| Workbench labels registry | `.github/labels.yml` | EXTRACTED |
| Workbench hardware registry | `docs/governance/DEVICE_IDENTITY_SSOT.md` | EXTRACTED (identity only, not full hardware) |
| Workbench SSOT registry | `docs/governance/SSOT_REGISTRY.yaml` | EXTRACTED |
| Workbench repo structure authority | `docs/governance/REPO_STRUCTURE_AUTHORITY.md` | EXTRACTED |
| Workbench compose authority | `docs/governance/COMPOSE_AUTHORITY.md` | EXTRACTED |
| Workbench portability assumptions | `docs/governance/PORTABILITY_ASSUMPTIONS.md` | EXTRACTED |
| Workbench agent boundaries | `docs/core/CAPABILITIES_OVERVIEW.md` (partial) | PARTIAL |
| Workbench issue closure SOP | `docs/governance/ISSUE_CLOSURE_SOP.md` | EXTRACTED |
| Workbench infrastructure map (schema/DB) | `docs/governance/INFRASTRUCTURE_MAP.md` (historical capture) | EXTRACTED (historical) |
| Workbench incidents log | Not extracted | NOT EXTRACTED |
| Workbench agents inventory (data) | Not extracted | NOT EXTRACTED (see below) |
| Workbench updates inventory (data) | Not extracted | NOT EXTRACTED |

---

## Agent Scripts Inventory

The workbench contains ~35 agent scripts in `scripts/agents/`. Most are legacy
one-off automation that predates the spine capability model.

**Categories:**

| Category | Count | Spine Status |
|----------|-------|-------------|
| Audit/verify scripts | ~10 | Replaced by drift gates (D1–D27) |
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

### Medium Priority (useful but not blocking)

1. **INCIDENTS_LOG** — Historical incident context. Could be a spine-scoped
   subset for infrastructure incidents that affect spine operations.

2. **AGENT_BOUNDARIES completion** — CAPABILITIES_OVERVIEW covers what agents
   can do but doesn't fully replicate the boundary constraints from the workbench.

3. **Agents inventory + updates inventory (data)** — Optional machine-readable
   inventories for domain agents and routine updates. Only extract if it reduces
   operational ambiguity (avoid duplication for its own sake).

---

## Infrastructure Pillar: ronny-ops → Workbench

> **Purpose:** Track extraction of infrastructure assets from `~/ronny-ops/infrastructure/`
> into `~/code/workbench/` so agents work entirely from `/Code`.
>
> **Capability:** `ops cap run infra.extraction.status` (receipt-producing, 23 asset groups)
> **Docs check:** `ops cap run docs.status` (verifies file counts per directory)

| # | Asset Group | Source (ronny-ops) | Target (workbench) | Min Files | Status |
|---|-------------|-------------------|-------------------|-----------|--------|
| 1 | runbooks | `docs/runbooks/` | workbench infra runbooks (docs tree, quarantined) | 30 | EXTRACTED |
| 2 | reference | `docs/reference/` | workbench infra references (docs tree, quarantined) | 16 | EXTRACTED |
| 3 | locations | `docs/locations/` | workbench infra locations (docs tree, quarantined) | 2 | EXTRACTED |
| 4 | hardware | `docs/hardware/` | workbench infra hardware (docs tree, quarantined) | 2 | EXTRACTED |
| 5 | architecture | `docs/architecture/` | workbench infra architecture (docs tree, quarantined) | 4 | EXTRACTED |
| 6 | audits | `audits/` + `docs/audits/` | workbench infra audits (docs tree, quarantined) | 5 | EXTRACTED |
| 7 | cloudflare-docs | `cloudflare/` + `docs/cloudflare/` | workbench infra cloudflare docs (docs tree, quarantined) | 3 | EXTRACTED |
| 8 | domains | `domains/` | workbench infra domains (docs tree, quarantined) | 2 | EXTRACTED |
| 9 | guides | `docs/guides/` | workbench infra guides (docs tree, quarantined) | 6 | EXTRACTED |
| 10 | homelab | `docs/homelab/` | workbench infra homelab docs (docs tree, quarantined) | 3 | EXTRACTED |
| 11 | rag-docs | `docs/rag/` | workbench infra RAG docs (docs tree, quarantined) | 6 | EXTRACTED |
| 12 | secrets-docs | `docs/secrets/` | workbench infra secrets docs (docs tree, quarantined) | 2 | EXTRACTED |
| 13 | authority-docs | top-level `*.md` + `*.yaml` | workbench infra authority docs (docs tree, quarantined) | 18 | EXTRACTED |
| 14 | mcp-docs | `mcpjungle/docs/` + `RECOVERY_RUNBOOK` | workbench infra MCP docs (docs tree, quarantined) | 3 | EXTRACTED |
| 15 | microsoft-docs | `microsoft/` | workbench infra Microsoft docs (docs tree, quarantined) | 2 | EXTRACTED |
| 16 | n8n-docs | `n8n/*.md` + `n8n/runbooks/` | workbench infra n8n docs (docs tree, quarantined) | 3 | EXTRACTED |
| 17 | compose-stacks | `mcpjungle/`, `n8n/`, `dashy/`, etc. | `infra/compose/` | 8 | EXTRACTED |
| 18 | n8n-workflows | `n8n/workflows/` | `infra/compose/n8n/workflows/` | 30 | EXTRACTED |
| 19 | mcpjungle | `mcpjungle/` (compose + servers) | `infra/compose/mcpjungle/` | 10 | EXTRACTED |
| 20 | data-inventories | `data/` | `infra/data/` | 6 | EXTRACTED |
| 21 | templates | `templates/` | `infra/templates/` | 5 | EXTRACTED |
| 22 | cloudflare-ops | `cloudflare/` (tunnel + exports) | `infra/cloudflare/` | 3 | EXTRACTED |
| 23 | dotfiles-ssh | `dotfiles/ssh/` | excluded (not referenced in spine) | 3 | EXTRACTED |

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
