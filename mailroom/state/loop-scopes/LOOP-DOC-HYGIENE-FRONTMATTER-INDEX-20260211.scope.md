---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-DOC-HYGIENE-FRONTMATTER-INDEX-20260211
severity: low
---

# Loop Scope: LOOP-DOC-HYGIENE-FRONTMATTER-INDEX-20260211

## Goal

Remediate GAP-OP-108: add YAML front-matter to root docs and expand
GOVERNANCE_INDEX.md auto-generated appendix.

## Acceptance Criteria

1. AGENTS.md has document-level YAML front-matter — DONE
2. Root README.md has YAML front-matter — DONE
3. GOVERNANCE_INDEX.md appendix regenerated (21 → 67 docs) — DONE
4. D58 freshness lock PASS — DONE
5. GAP-OP-108 status changed to fixed — DONE

## Phases

| Phase | Scope | Status | Commit/Proposal |
|-------|-------|--------|-----------------|
| P0 | Loop registration + gap re-parenting | DONE | b9fe92e |
| P1 | Front-matter + index fixes | DONE | CP-20260211-175600 (this commit) |
| P2 | Validate + close | DONE | (this commit) |
