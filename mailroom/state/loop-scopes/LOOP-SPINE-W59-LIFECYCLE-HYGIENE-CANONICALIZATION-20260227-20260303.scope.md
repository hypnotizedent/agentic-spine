---
loop_id: LOOP-SPINE-W59-LIFECYCLE-HYGIENE-CANONICALIZATION-20260227-20260303
created: 2026-02-27
status: active
owner: "@ronny"
scope: spine-lifecycle-hygiene
priority: high
objective: Enforce lifecycle hygiene for receipts, branches/worktrees, and stale artifacts.
---

# Loop Scope: LOOP-SPINE-W59-LIFECYCLE-HYGIENE-CANONICALIZATION-20260227-20260303

## Objective
Stop recurrence of cleanup crumbs by enforcing receipt completeness and staged cleanup phases.

## Included
- Receipt closeout lifecycle
- Worktree/branch cleanup lifecycle
- Archive/tombstone lifecycle for stale artifacts
- Freshness checks for untouched high-risk surfaces (>7 days)

## Success Criteria
- Cleanup runs follow report-only -> archive-only -> delete(token-gated).
- Receipt completeness lock is enforced before worktree removal.
- Stale artifacts are classified as refresh, archive, or tombstone with evidence.

## Definition Of Done
- Lifecycle guard contract committed.
- Report-only branch hygiene inventory committed.
- Token-gated deletion protocol committed.
