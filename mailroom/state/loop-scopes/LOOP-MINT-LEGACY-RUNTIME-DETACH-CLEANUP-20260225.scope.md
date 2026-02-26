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

## Non-Destructive Stop-Only Batch (2026-02-26)

Operator-approved scope executed:
1. Classification-only receipts capture.
2. Stop-only action on duplicate legacy module containers:
   `files-api`, `quote-page`, `order-intake`.
3. No delete actions.
4. No volume mutation.
5. No backup-path mutation.

Pre-state receipts:
- `CAP-20260226-025944__infra.docker_host.status__Rjvkg12345`
- `CAP-20260226-025944__docker.compose.status__Rtdb312465`
- `CAP-20260226-025949__services.health.status__Ra8ul20384`
- `CAP-20260226-025949__cloudflare.tunnel.ingress.status__Rn32b20389`
- `CAP-20260226-025949__cloudflare.domain_routing.diff__R06h120405`

Stop-only command result (ssh execution, non-destructive):
1. `files-api` exited.
2. `quote-page` exited.
3. `order-intake` exited.
4. `docker ps` confirms no running duplicate containers in `mint-modules-prod`.

Post-state receipts:
- `CAP-20260226-030538__infra.docker_host.status__R4hgd53429`
- `CAP-20260226-030538__docker.compose.status__R0a5l53430`
- `CAP-20260226-030538__mint.modules.health__Riuj853431`
- `CAP-20260226-030538__mint.runtime.proof__Ricct53432`
- `CAP-20260226-030538__mint.live.baseline.status__R41w853433`

Observed outcome:
1. Docker-host duplicate module runtime path is inactive (containers stopped).
2. Fresh-slate mint runtime remains healthy (`mint.modules.health` and
   `mint.runtime.proof` both `OK`).
3. Loop remains deferred for any destructive cleanup phase.

## Mint-Modules Contract Alignment Reviewed

Validated against:
1. `/Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md`
2. `/Users/ronnyworks/code/mint-modules/docs/CANONICAL/NO_LEGACY_COUPLING.md`
3. `/Users/ronnyworks/code/mint-modules/docs/CANONICAL/ACTIVE_AUTHORITY.md`

Contract alignment note:
1. Active runtime authority remains mint-apps (VM 213) + mint-data (VM 212).
2. Legacy docker-host runtime is `LEGACY_ONLY` / non-authoritative.
3. Stop-only detachment is consistent with zero-legacy-coupling policy.

## Legacy Data Hold Artifact (2026-02-26)

Manifest:
- `/Users/ronnyworks/code/agentic-spine/docs/planning/MINT_LEGACY_DATA_HOLD_MANIFEST_20260226.md`

Raw snapshot receipt:
- `/Users/ronnyworks/code/agentic-spine/receipts/audits/LEGACY_DATA_HOLD_RECEIPT_20260226T081048Z.txt`
