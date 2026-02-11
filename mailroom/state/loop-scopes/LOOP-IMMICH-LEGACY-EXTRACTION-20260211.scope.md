---
status: active
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-IMMICH-LEGACY-EXTRACTION-20260211
severity: high
---

# Loop Scope: LOOP-IMMICH-LEGACY-EXTRACTION-20260211

## Goal

Extract critical Immich operational knowledge from legacy source into spine-native governed docs before legacy source becomes unavailable. Promote only spine-compatible outputs per `docs/core/EXTRACTION_PROTOCOL.md`.

## Problem / Current State (2026-02-11)

- Immich (VM 203) is a running service with 135K+ assets (3TB library) and 4 users.
- Spine has device identity, VM-level backup targets, and secrets namespace for Immich.
- Spine has **zero** app-level operational coverage: no backup/restore procedures, no deduplication governance, no service registry entry, no health check, no compose target.
- All app-level operational knowledge exists only in legacy `ronny-ops/immich/` (commit `1ea9dfa`).
- Daily PostgreSQL backup script on VM may reference legacy path — silent failure risk.
- The previous media legacy extraction loop (`LOOP-MEDIA-LEGACY-EXTRACTION-20260211`) covered media-stack (VM 209/210) but not Immich (VM 203). That loop is now closed.
- Legacy local path `~/ronny-ops` was removed for D30 compliance. Remote source: `https://github.com/hypnotizedent/ronny-ops.git`.

## Extraction Contract (No Garbage Import)

- Follow `docs/core/EXTRACTION_PROTOCOL.md`:
  - Move A first (doc-only snapshot and rewrite).
  - Move B only for small, clean, governed wrappers.
- No direct runtime dependency on legacy source.
- No blind copy/paste of legacy markdown or scripts.
- Every promoted artifact must include: owner, authority/scope, verification method, receipts.

## Extraction Matrix Reference

Full extraction matrix with coverage analysis, loss-if-deleted report, and extraction decisions:
`docs/governance/IMMICH_LEGACY_EXTRACTION_MATRIX.md`

## Classification

**Recommended:** Upgrade Immich from Utility to Stack in `EXTRACTION_PROTOCOL.md`.

Justification: 4 containers, 3TB data, custom backup topology (pg_dump + library rsync + offsite), deduplication governance (THE RULE), multi-user management, planned MCP tooling. Decision tree evaluates to STACK (3-10 containers, lessons + runbook needed).

## Success Criteria

- 2 spine-native docs created: `IMMICH_BACKUP_RESTORE.md` + `IMMICH_OPERATIONS_LESSONS.md`
- 3 registry entries added: SERVICE_REGISTRY, STACK_REGISTRY, services.health
- Classification updated in EXTRACTION_PROTOCOL.md
- Extraction matrix governs all dispositions
- Cron path verified on immich-1 VM
- `spine.verify` passes

## Phases

- P0: COMPLETE -- Terminal D audit: inventory legacy artifacts, assess spine coverage, produce extraction matrix.
- P1: PENDING -- Verify cron path on immich-1 VM; confirm daily DB backup is functional.
- P2: PENDING -- Rewrite spine-native docs (Move A): `IMMICH_BACKUP_RESTORE.md` + `IMMICH_OPERATIONS_LESSONS.md`.
- P3: PENDING -- Registry entries: SERVICE_REGISTRY + STACK_REGISTRY + services.health + classification upgrade.
- P4: PENDING -- Validate (`spine.verify`) and close with receipt-linked summary.

## Notes

- Immich is a separate service (VM 203) from media-stack (VM 209/210); gets its own extraction loop.
- CRITICAL operational alert: verify cron on immich-1 before P2 — daily DB backup may be silently failing.
- MCP server spec (`infrastructure/mcpjungle/servers/immich-photos/SPEC.md`) deferred to future loop when implementation begins.
- Deduplication scripts (`.archive/2026-01-05-full-reset/scripts/dedupe/`) deferred to future tooling loop.
