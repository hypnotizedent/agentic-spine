---
loop_id: LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225
created: 2026-02-25
status: deferred
owner: "@ronny"
scope: mint
severity: critical
objective: Remove split-brain risk by detaching duplicate mint-modules runtime behavior from legacy docker-host path
---

# Loop Scope: LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225

## Problem Statement

Audit evidence indicates legacy docker-host and fresh-slate mint-apps signals are
being conflated. Some reports also indicate duplicate mint-modules behavior on the
legacy host, creating split-brain risk and misleading "live" claims.

## Deliverables

1. Produce definitive runtime classification:
   `LIVE_SPINE_NATIVE`, `LEGACY_DOCKER_HOST`, `PARTIAL_MIGRATION`.
2. For module-equivalent services, remove duplicate legacy runtime paths after
   operator approval.
3. Mark legacy-only services as explicit `legacy-hold` and non-authoritative for
   spine-native claims.
4. Update routing/registry docs to reflect deprecated legacy paths.

## Acceptance Criteria

1. No module-equivalent mint runtime on docker-host remains classified as active
   authoritative runtime.
2. Fresh-slate module public routes resolve to mint-apps targets only.
3. Legacy portals remain clearly labeled legacy and out of spine-native proof path.
4. Changes are receipt-backed with before/after runtime evidence.

## Constraints

1. No new feature builds.
2. No auth implementation.
3. Legacy host is not a development target; only deprecation/cleanup actions are
   allowed in this loop.
4. Do not claim legacy runtime behavior as current module truth.

## Operator Hold (2026-02-26)

This loop is intentionally deferred by operator direction pending explicit data-risk
review. Execution mode is restricted to non-destructive reads and classification
updates only.

## What This Loop Does (When Resumed)

1. Classify runtime authority (`LIVE_SPINE_NATIVE` vs `LEGACY_DOCKER_HOST`) with
   before/after receipts.
2. Remove only approved duplicate legacy runtime paths after explicit operator go.
3. Keep legacy-hold data areas preserved until separately approved for archive or
   migration.

## What You Could Lose If Destructive Steps Are Approved Later

Potentially destructive targets (must remain protected unless separately approved):
1. `/home/docker-host/backups` (~3.2G historical backups/receipts).
2. `/mnt/data/mint-os/postgres` (~1.5G legacy database state).
3. `/mnt/docker/mint-os-data/minio` (legacy MinIO buckets such as
   `customer-artwork`, `production-files`, `imprint-mockups`).
4. `/home/docker-host/stacks/mail-archiver/postgres-data` (~8.6G).
5. `/mnt/docker/hypno-ssot` (~57G non-mint business asset corpus).

## Non-Destructive Contract (Enforced For This Loop)

1. No `rm -rf` on data-bearing paths.
2. No `docker compose down -v`.
3. No `docker volume rm` for mint/mail/hypno data lanes.
4. No backup directory mutation under `/home/docker-host/backups`.
5. Allowed actions: read-only capability runs, classification docs, and risk
   receipts only.

## Evidence Snapshot (Read-Only)

Capability run keys:
- `CAP-20260226-024059__infra.docker_host.status__R9h1f30554`
- `CAP-20260226-024150__docker.compose.status__Rp0ji36887`
- `CAP-20260226-024059__services.health.status__Rxu6p30556`
