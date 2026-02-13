---
id: LOOP-DOC-SPRAWL-TIGHTEN-20260213
status: closed
opened: 2026-02-13
owner: "@ronny"
terminal: C
parent_discovery: CP-20260213-1205__docs-core-upgrade-discovery
---

# LOOP: Doc Sprawl Tighten

## Objective

Execute docs tightening based on discovery CP findings. Prevent future sprawl via self-management hardening.

## Scope

### Lane D — Index + Registry Parity
- Add 9 missing governance docs to `docs/governance/_index.yaml`
- Ensure ACTIVE_DOCS_INDEX.md and README.md parity

### Lane E — Metadata/Freshness Normalization
- Add lifecycle frontmatter to INFRASTRUCTURE_AUTHORITY.md, CONTRIBUTING.md, MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK.md

### Lane F — Archive/Promote/Condense
- Archive 21 brain lesson files to `docs/legacy/brain-lessons/`
- Promote context.md and memory.md to ACTIVE_DOCS_INDEX
- Merge HOME_BACKUP_STRATEGY.md into BACKUP_GOVERNANCE.md

### Lane G — Broken Refs + Path Hygiene
- Fix broken refs in ACTIVE_DOCS_INDEX.md and README.md
- Normalize legacy path references in governance docs

### Self-Management Hardening
- Add drift gate(s) for docs lifecycle enforcement
- Add policy binding for doc registration requirements

## Gaps
- GAP-OP-254: Index parity + discoverability
- GAP-OP-255: Metadata/freshness normalization
- GAP-OP-256: Broken refs + canonical path normalization
- GAP-OP-257: Archive/promote/condense execution
- GAP-OP-258: Self-management hardening

## Exit Criteria
- All 5 gaps closed with evidence
- spine.verify passes (all gates)
- gaps.status shows 0 open
- Both remotes synced
