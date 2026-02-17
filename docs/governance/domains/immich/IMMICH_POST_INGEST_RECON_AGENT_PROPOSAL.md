---
status: draft
owner: "@ronny"
last_verified: 2026-02-17
scope: immich-post-ingest-reconciliation-agent
---

# IMMICH Post-Ingest Reconciliation Agent Proposal (V1)

## Objective

After yearly ingest completes, run a dedicated reconciliation agent that identifies and stages duplicate cleanup decisions while preserving original assets with the richest metadata.

## Why Now

1. Yearly ingest is now autonomous and stable.
2. Duplicate/isolation work is currently manual and fragmented.
3. A governed reconciliation lane reduces risk and prevents ad-hoc deletions.

## Policy (Canonical)

1. Originals first: prefer the asset with the strongest original metadata.
2. Signal stack: `SHA` exact match, `pHash` perceptual match, `EXIF` richness.
3. Resolution is not the primary keeper signal.
4. No hard deletes by default; actions are staged as manifests.

## Agent Responsibilities

1. Build an exact-duplicate ledger grouped by `checksum` (`SHA`).
2. Build a perceptual-duplicate ledger grouped by `thumbhash`/`pHash`.
3. Score metadata richness per asset from EXIF/detail fields.
4. Produce deterministic keep/drop recommendations with explicit reasons.
5. Output replayable manifests for review and apply.

## Proposed Capabilities

1. `immich.reconcile.scan` (read-only)
2. `immich.reconcile.plan` (read-only)
3. `immich.reconcile.review` (read-only report pack)
4. `immich.reconcile.apply` (mutating, manual approval)
5. `immich.reconcile.rollback` (mutating, manual approval)

## Output Artifacts

1. `reports/reconcile/sha_groups_<ts>.json|csv`
2. `reports/reconcile/phash_groups_<ts>.json|csv`
3. `reports/reconcile/keep_drop_plan_<ts>.json`
4. `reports/reconcile/apply_manifest_<ts>.yaml`
5. `reports/reconcile/rollback_manifest_<ts>.yaml`

## Safety Model

1. Default mode: dry-run only.
2. Apply mode requires explicit operator approval.
3. Every mutation path emits rollback manifest.
4. Apply batches are small and idempotent.

## Keeper Decision Order (Deterministic)

1. Prefer non-trashed asset.
2. Prefer asset with higher EXIF richness score.
3. Prefer earlier `localDateTime` when tie exists.
4. Prefer path/name without copy-suffix patterns (`(1)`, `(2)`, `_copy`).
5. Final tie-break by stable UUID sort.

## Delivery Plan

1. Phase 1: scanning + ledgers (no mutations).
2. Phase 2: planner + confidence scoring.
3. Phase 3: apply/rollback with guardrails.
4. Phase 4: nightly drift report for new duplicates.

## Success Criteria

1. Full duplicate ledger generated from current corpus.
2. All recommendations are explainable and reproducible.
3. Zero uncontrolled deletes.
4. Operator can isolate and action duplicate clusters quickly.
