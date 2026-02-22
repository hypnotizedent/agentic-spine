# AOF Alignment Audit: docs/

> **Audit Date:** 2026-02-16
> **Target Folder:** `/Users/ronnyworks/code/agentic-spine/docs`
> **Total Files:** 293 (234 .md + 59 other)
> **Auditor:** Sisyphus (automated)

---

## Executive Summary

The `docs/` folder contains the authoritative documentation for the Agentic Operations Framework (AOF). Most files are correctly placed within the spine runtime. However, the `legacy/` subfolder contains 82 files that represent imported historical artifacts from `ronny-ops` that should be evaluated for removal or relocation.

---

## KEEP_SPINE (Authoritative Spine Docs)

**Count:** 211 files
**Status:** Correctly placed - these define the spine's governance, contracts, and operational surface.

| Path | File Count | Rationale |
|------|------------|-----------|
| `/Users/ronnyworks/code/agentic-spine/docs/core/` | 24 | Core contracts, invariants, bindings - spine invariants per AOF_PRODUCT_CONTRACT |
| `/Users/ronnyworks/code/agentic-spine/docs/governance/` | 155 | SSOTs, authority pages, drift gates, capability contracts - authoritative governance |
| `/Users/ronnyworks/code/agentic-spine/docs/product/` | 9 | AOF productization artifacts (product contract, acceptance gates, SLO) |
| `/Users/ronnyworks/code/agentic-spine/docs/brain/` | 10 | Agent memory system, context injection - runtime agent surface |
| `/Users/ronnyworks/code/agentic-spine/docs/jd/` | 4 | Johnny Decimal taxonomy system - doc organization spine |
| `/Users/ronnyworks/code/agentic-spine/docs/pillars/` | 3 | Domain pointer stubs (valid per D65 pointer-shim pattern) |
| `/Users/ronnyworks/code/agentic-spine/docs/planning/` | 1 | Spine infrastructure bootstrap runbook |
| `/Users/ronnyworks/code/agentic-spine/docs/*.md` | 5 | Root index docs (README, CONTRIBUTING, ACTIVE_DOCS_INDEX, OPERATOR_CHEAT_SHEET) |

**Key Files:**
- `/Users/ronnyworks/code/agentic-spine/docs/core/CORE_LOCK.md` - Drift gates D1-D84
- `/Users/ronnyworks/code/agentic-spine/docs/governance/AGENT_GOVERNANCE_BRIEF.md` - Embedded governance brief
- `/Users/ronnyworks/code/agentic-spine/docs/product/AOF_PRODUCT_CONTRACT.md` - Product boundary definition
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SSOT_REGISTRY.yaml` - Truth source priority

---

## MOVE_WORKBENCH (Domain-Specific/Compose Artifacts)

**Count:** 21 files
**Status:** Should relocate to workbench - domain-specific operational docs not part of spine core.

| Path | File Count | Rationale |
|------|------------|-----------|
| `/Users/ronnyworks/code/agentic-spine/docs/legacy/brain-lessons/` | 18 | Domain-specific lessons (finance, media, home) - belong in workbench domain folders |
| `/Users/ronnyworks/code/agentic-spine/docs/pillars/finance/ARCHITECTURE.md` | 1 | Duplicate of workbench domain doc - pointer stub exists, full doc redundant |
| `/Users/ronnyworks/code/agentic-spine/docs/pillars/finance/EXTRACTION_STATUS.md` | 1 | Extraction tracking - belongs in workbench or should be deleted if complete |
| `/Users/ronnyworks/code/agentic-spine/docs/governance/GRAPH_*.md` | 3 | MS Graph domain runbooks duplicated in `domains/ms-graph/` |

**Recommendation:**
1. Move `legacy/brain-lessons/` to `/Users/ronnyworks/code/workbench/docs/brain-lessons/`
2. Remove `pillars/finance/ARCHITECTURE.md` and `EXTRACTION_STATUS.md` - pointer stub is sufficient
3. Consolidate `governance/GRAPH_*.md` into `governance/domains/ms-graph/` and remove duplicates

---

## RUNTIME_ONLY (Non-Source-Controlled Artifacts)

**Count:** 6 files
**Status:** Should be gitignored or removed - runtime artifacts, not source.

| Path | File Count | Rationale |
|------|------------|-----------|
| `/Users/ronnyworks/code/agentic-spine/docs/.DS_Store` | 1 | macOS folder metadata |
| `/Users/ronnyworks/code/agentic-spine/docs/legacy/.DS_Store` | 1 | macOS folder metadata |
| `/Users/ronnyworks/code/agentic-spine/docs/pillars/.DS_Store` | 1 | macOS folder metadata |
| `/Users/ronnyworks/code/agentic-spine/docs/legacy/_imports/ronny-ops_20260201_024236/scripts/ops/ops.bak.*` | 1 | Backup file - not source |

**Recommendation:**
1. Add `**/.DS_Store` to `.gitignore` if not present
2. Delete existing `.DS_Store` files from git tracking
3. Remove backup files from `legacy/_imports/`

---

## UNKNOWN (Needs Review)

**Count:** 55 files
**Status:** Legacy script imports with unclear operational status.

| Path | File Count | Issue |
|------|------------|-------|
| `/Users/ronnyworks/code/agentic-spine/docs/legacy/_imports/ronny-ops_20260201_024236/scripts/` | 55 | Superseded scripts - may have been replaced by capabilities |

### Subclassification Needed:

**Likely RUNTIME_ONLY (superseded by capabilities):**
- `scripts/agents/*.sh` - Agent scripts replaced by `ops/plugins/*/bin/` capabilities
- `scripts/infra/*.sh` - Infrastructure scripts replaced by `ops/capabilities/infra.*`
- `scripts/ops/commands/*.sh` - Ops commands replaced by `ops/` CLI

**Likely MOVE_WORKBENCH (reference value):**
- `scripts/ops/lib/*.sh` - Library functions that may have invariants worth extracting
- `.claude/commands/*.md` - Legacy command templates, superseded by spine surfaces

---

## Top 10 Highest-Risk Mismatches

| Rank | File | Risk | Issue | Recommended Action |
|------|------|------|-------|-------------------|
| 1 | `docs/legacy/_imports/ronny-ops_20260201_024236/scripts/ops/ops` | HIGH | Executable binary in docs/ - violates docs-are-docs principle | DELETE (superseded by `bin/ops`) |
| 2 | `docs/legacy/_imports/ronny-ops_20260201_024236/scripts/ops/ops.bak.*` | HIGH | Backup file in source tree | DELETE |
| 3 | `docs/legacy/brain-lessons/*.md` (18 files) | MEDIUM | Domain-specific docs in spine | MOVE to workbench |
| 4 | `docs/governance/GRAPH_*.md` (3 files) | MEDIUM | Duplicate of `domains/ms-graph/` | CONSOLIDATE |
| 5 | `docs/pillars/finance/ARCHITECTURE.md` | MEDIUM | Full doc where pointer stub exists | DELETE (pointer is sufficient) |
| 6 | `docs/.DS_Store` (3 files) | LOW | macOS metadata in git | GITIGNORE + DELETE |
| 7 | `docs/legacy/_imports/ronny-ops_20260201_024236/scripts/agents/*.sh` (28 files) | LOW | Superseded scripts | REVIEW and DELETE |
| 8 | `docs/legacy/_imports/ronny-ops_20260201_024236/scripts/infra/*.sh` (7 files) | LOW | Superseded scripts | REVIEW and DELETE |
| 9 | `docs/legacy/_imports/ronny-ops_20260201_024236/.claude/commands/*.md` (5 files) | LOW | Legacy command templates | DELETE if superseded |
| 10 | `docs/pillars/finance/EXTRACTION_STATUS.md` | LOW | Extraction tracking artifact | DELETE if extraction complete |

---

## Summary Table

| Category | Count | Action |
|----------|-------|--------|
| KEEP_SPINE | 211 | No action - correctly placed |
| MOVE_WORKBENCH | 21 | Relocate to workbench |
| RUNTIME_ONLY | 6 | Gitignore/remove |
| UNKNOWN | 55 | Review for deletion |

---

## Recommended Next Steps

1. **Immediate:** Delete `.DS_Store` files and backup files
2. **Short-term:** Move `legacy/brain-lessons/` to workbench
3. **Short-term:** Consolidate duplicate GRAPH_*.md files
4. **Medium-term:** Review legacy `_imports/` folder for complete deletion
5. **Governance:** Add explicit drift gate for "no executables in docs/" (currently implicit via D16/D17)

---

## Audit Signature

- **Audited by:** Sisyphus (automated analysis)
- **Method:** Full file enumeration + classification against AOF_PRODUCT_CONTRACT
- **Confidence:** HIGH for KEEP_SPINE/MOVE_WORKBENCH, MEDIUM for UNKNOWN (requires manual review)
