---
status: authoritative
owner: "@ronny"
created: 2026-02-25
scope: mint-payment-runtime-readiness
authority: LOOP-MINT-PAYMENT-RUNTIME-READINESS-20260225
---

# Mint Payment Runtime Readiness Contract (2026-02-25)

## Purpose

Provide a binary readiness state for payment runtime without overstating end-to-end capabilities.

## Allowed Outcomes

1. `NOT_LIVE`
2. `READY_FOR_RONNY_STAMP`

No other outcome wording is allowed.

## Required Evidence

Each payment readiness review must include run keys for:
1. `mint.modules.health`
2. `mint.deploy.status`
3. `mint.runtime.proof`
4. `mint.live.baseline.status`
5. optional targeted payment smoke evidence

## Readiness Preconditions

1. Payment service health endpoint responds successfully.
2. Required payment env keys are present in runtime container.
3. No contradiction between health/deploy/proof outcomes for payment lane.

## Explicit Defers

1. `payment->finance` bridge implementation is deferred.
2. Order-lifecycle automation claims are deferred.
3. Auth extraction remains deferred until separately approved.

## Classification Rule

If any precondition fails -> `NOT_LIVE`.
If all preconditions pass and Ronny test stamp exists -> `READY_FOR_RONNY_STAMP`.
