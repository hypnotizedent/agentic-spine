# Media Stack Holistic Forensic Trace (2026-03-03)

## Scope

This report is a governance-only forensic capture. It does not mutate runtime.
It reconstructs:

1. how the media stack got to the current state,
2. what is broken now,
3. and what is missing to safely execute a future shop-to-home migration.

## Authority Inputs

- `mailroom/state/loop-scopes/_archived/LOOP-MEDIA-STACK-SPLIT-20260208.scope.md`
- `mailroom/state/loop-scopes/LOOP-MEDIA-HISTORY-CANONICALIZATION-20260301.scope.md`
- `mailroom/state/loop-scopes/LOOP-MEDIA-MAINTAINERR-SEER-HUNTARR-RD-20260301.scope.md`
- `ops/bindings/infra.relocation.plan.yaml`
- `ops/bindings/media.services.yaml`
- `docs/governance/SERVICE_REGISTRY.yaml`
- `ops/bindings/operational.gaps.yaml` (media and connector gap sets)

## Executive Finding

The current issue is not a single "movie missing" bug. It is a contract-chain
drift problem:

- files can exist,
- one service can report healthy state,
- but cross-service path and status contracts can still be inconsistent.

That pattern is a direct continuation of split-era assumptions not being
enforced end-to-end at application boundaries.

## Timeline (How We Got Here)

1. **2026-02-08 split**
   VM 201 monolith was split to VM 209 download-stack and VM 210 streaming-stack.
   Infra split completed and legacy VM decommissioned.
2. **Post-split stabilization**
   Multiple path/connectivity issues were corrected over time, but mostly as
   local fixes.
3. **2026-03-01 remediation waves**
   Search/download control and some observability improved (Huntarr deprecation,
   native search scheduler, self-healing work).
4. **2026-03-03 forensic symptom**
   Files present on disk and `hasFile=true`, yet request and availability
   surfaces remained inconsistent.

## Current Disconnect Matrix

| Layer | Symptom | Canonical Gap |
|---|---|---|
| Path authority | Radarr root mismatch (`/movies` vs `/media/movies`) | GAP-OP-1387 |
| Download handoff | SAB/Radarr path mismatch (`/downloads/complete/movies`) | GAP-OP-1388 |
| Status truth | Jellyseerr `processing` while files already present | GAP-OP-1389 |
| Queue truth | `downloadClientUnavailable` ghost queue for completed titles | GAP-OP-1390 |
| Migration residue | Split-era path assumptions not normalized as a contract | GAP-OP-1391 |
| Verification | `hasFile=true` checks can false-green the user experience | GAP-OP-1392 |
| Operator friction | Superseded background failures remain noisy | GAP-OP-1393 |

## Root-Cause Chain

1. **Path contracts are not treated as a single authority object.**
   App root, compose mount, and downloader path can diverge.
2. **Availability status is multi-source without deterministic progression.**
   Radarr completion does not guarantee synchronized Jellyseerr/Jellyfin truth.
3. **Existing verification surfaces can pass before user-facing readiness.**
   Checks can over-trust partial signals.
4. **Migration history exists but future migration connector is missing.**
   There is no explicit shop-to-home transaction packet yet.

## Connector to Shop -> Home Migration

Planning anchor loop:
- `LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303`

Required connector deliverables:

1. **Target topology declaration**
   Define home target roles and what remains shop-hosted vs relocated.
2. **Path parity contract**
   Require a four-way parity tuple:
   `compose mount -> app root -> downloader path -> library path`.
3. **Status progression contract**
   Canonical state progression across request/import/library surfaces.
4. **Transactional migration packet**
   Preflight, cutover, rollback, and post-cutover verification sequence.
5. **Operator-ready execution packet**
   One packet consumable by a worker/orchestrator terminal without rediscovery.

## New Connector Gaps

- GAP-OP-1402..1406 capture missing planning surfaces that block a safe
  shop-to-home media migration execution wave.

## Recommended Next Wave Order

1. Resolve path authority contract and gate coverage (GAP-OP-1387/1388/1391/1392).
2. Resolve status progression and queue reconciliation (GAP-OP-1389/1390).
3. Complete migration connector artifacts (GAP-OP-1402..1406).
4. Execute migration only after connector loop promotes from blocked to runnable.
