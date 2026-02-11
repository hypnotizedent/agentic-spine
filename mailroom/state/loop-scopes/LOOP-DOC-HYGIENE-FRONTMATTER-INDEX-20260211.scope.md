---
status: open
owner: "@ronny"
created: 2026-02-11
scope: loop-scope
loop_id: LOOP-DOC-HYGIENE-FRONTMATTER-INDEX-20260211
severity: low
---

# Loop Scope: LOOP-DOC-HYGIENE-FRONTMATTER-INDEX-20260211

## Goal

Remediate GAP-OP-108: add YAML front-matter to root docs (AGENTS.md, README.md)
and expand GOVERNANCE_INDEX.md auto-generated appendix to cover all governance docs.

## Problem

(a) AGENTS.md has governance brief front-matter inline but no document-level
front-matter (status/owner/last_verified). Root README.md has none at all.
(b) GOVERNANCE_INDEX.md auto-generated appendix lists 21 of ~67 governance docs.

## Acceptance Criteria

1. AGENTS.md has document-level YAML front-matter (status: authoritative)
2. Root README.md has YAML front-matter (status: authoritative)
3. GOVERNANCE_INDEX.md appendix covers all governance docs (or has regeneration tooling)
4. D58 freshness lock continues to PASS
5. GAP-OP-108 status changed to fixed

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Loop registration + gap re-parenting | DONE (this commit) |
| P1 | Add front-matter to root docs | PENDING |
| P2 | Expand GOVERNANCE_INDEX.md | PENDING |
| P3 | Validate + close GAP-OP-108 | PENDING |

## Registered Gaps

- GAP-OP-108: Minor doc hygiene from certification audit

## Notes

Low severity — cosmetic issues that don't block agents or gates. Policy decision
needed: should AGENTS.md have its own front-matter separate from the embedded
governance brief? D65 sync propagates the brief; adding doc-level front-matter
must not conflict with the sync mechanism.
