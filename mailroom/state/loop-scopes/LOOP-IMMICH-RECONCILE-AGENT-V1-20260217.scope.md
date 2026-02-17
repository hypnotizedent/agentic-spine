---
loop_id: LOOP-IMMICH-RECONCILE-AGENT-V1-20260217
status: active
priority: high
owner: "@ronny"
created: 2026-02-17
scope: immich-post-ingest-reconciliation-agent
parent_proposal: CP-20260217-070859__immich-post-ingest-reconciliation-agent-v1
---

# Immich Post-Ingest Reconciliation Agent V1

## Objective

Build governed capabilities for post-ingest duplicate detection and cleanup
using SHA + pHash + EXIF signals with dry-run-first, reversible apply/rollback.

## Workstreams

1. `immich.reconcile.scan` — Fetch duplicates from Immich API, group by SHA and pHash
2. `immich.reconcile.plan` — Score EXIF richness, apply keeper decision order, produce keep/drop plan
3. `immich.reconcile.review` — Human-readable summary of the plan
4. `immich.reconcile.apply` — Execute plan (trash drops), write rollback manifest
5. `immich.reconcile.rollback` — Reverse a prior apply batch

## Constraints

- No destructive action by default (dry-run first)
- Keep decisions must be deterministic and explainable
- Apply mode must be manually approved and reversible
- Must not interfere with active yearly ingest

## Exit Criteria

- All 5 capabilities registered, passing verify
- Scan/plan/review emit reports with receipts
- Apply is guarded and writes rollback manifest
- Rollback can reverse a prior apply batch
