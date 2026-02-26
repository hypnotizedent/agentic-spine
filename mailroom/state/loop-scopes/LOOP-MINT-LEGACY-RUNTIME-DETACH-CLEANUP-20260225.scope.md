---
loop_id: LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225
created: 2026-02-25
status: active
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

