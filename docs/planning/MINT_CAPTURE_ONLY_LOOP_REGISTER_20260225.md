---
status: authoritative
owner: "@ronny"
created: 2026-02-25
scope: mint-capture-loop-register
authority: CAPTURE-ONLY-SYNTHESIS-20260225
---

# Mint Capture-Only Loop Register (2026-02-25)

## Purpose

Synthesize multi-terminal audit output into one cleanup loop register without
claiming unverified runtime behavior.

## Operator Truth Policy (Locked)

1. Trusted live baseline is only:
   - agent submits quote form
   - Ronny receives email
   - files visible in MinIO
2. Everything else is untrusted until Ronny test stamp.
3. Defer auth work.
4. Defer unbuilt capabilities/modules.
5. No legacy runtime dependency in target architecture.
6. No old docker-host conflation with mint-apps/mint-data runtime.

## Evidence Synthesis

### Stable Facts Across Reports

1. `mint.intake.validate` path fix was applied to `/api/v1/intake/validate`.
2. SSOT roadmap documents were created/linked in mint-modules.
3. Legacy docker-host remains active and is still present in contracts/governance
   references.
4. Auth/order-lifecycle/notifications are not approved as live end-to-end paths.
5. Payment runtime state is inconsistent across reports and requires explicit
   re-validation.

### Conflicting Evidence (Must Resolve Before Any "Works" Claim)

1. `mint.modules.health` reported both all-green and partial failures in
   different runs.
2. `mint.runtime.proof` reported both pass and fail in different runs.
3. Payment module reported both live and deploy-blocked states across summaries.
4. Legacy/public routing claims differ between reports (fresh-slate vs legacy API).

## Registered Loops (Execution Order)

1. `LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225`
2. `LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225`
3. `LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225`
4. `LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225`
5. `LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225`

## Current State Snapshot (2026-02-26)

1. `LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225` -> `closed`
2. `LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225` -> `closed`
3. `LOOP-MINT-LEGACY-RUNTIME-DETACH-CLEANUP-20260225` -> `deferred` (operator hold; non-destructive only)
4. `LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225` -> `active` (`NOT_LIVE`, awaiting explicit smoke/stamp evidence)
5. `LOOP-MINT-SSOT-DOC-RUNTIME-ALIGNMENT-20260225` -> `active`

## Out of Scope (Explicit Defers)

1. Auth extraction/implementation.
2. New order-lifecycle build.
3. New notifications/comms implementation.
4. Supplier order-placement mutations.
5. Any legacy docker-host feature investment.

## Handoff Rule

Cleanup terminals execute loops in order. No loop advances until the prior loop
has receipt-backed completion and Ronny stamp where required.
