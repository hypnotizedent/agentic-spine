---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-22
scope: audits-migration-targets
---

# Audits Migration Targets V1

## Purpose
Define deterministic, non-destructive target mapping for migrating `docs/governance/_audits/**` into receipts archive surfaces.

## Canonical Destinations
- `receipts/audits/<domain>/<YYYY>/<MM>/`
- `receipts/audits/_shared/<YYYY>/<MM>/`
- `docs/governance/_audits/KEEP/` (governance-contract records only)

## Deterministic Path Rules
1. Preserve filename exactly.
2. Extract date bucket from source path/filename:
   - Preferred: `YYYY-MM-DD` token
   - Fallback: `YYYYMMDD` token
   - Final fallback: source file modified time (UTC)
3. Resolve domain from source path tokens:
   - Domain keywords map to canonical domains (for example: `communications`, `microsoft`, `home`, `mint`, `n8n`, `finance`, `infra`, `rag`, `workbench`, `secrets`, `aof`, `core`).
   - If no deterministic domain match exists, route to `_shared`.
4. Classification routing:
   - `evidence_runtime` -> receipts destination (`<domain>` or `_shared`)
   - `governance_contract` -> `docs/governance/_audits/KEEP/<filename>`
   - `unknown_review` -> candidate receipts destination with `migration_action: review` until operator decision

## Wave H1 Artifacts
- Inventory: `docs/governance/_audits/MIGRATION_INVENTORY_20260222.yaml`
- Dry-run plan: `ops/bindings/audits.migration.plan.yaml`

## Notes
- Wave H1 is planning only; no `mv`/`rm` operations are permitted.
- Execution wave (H2) must consume the approved dry-run plan and emit receipts for every applied action.
