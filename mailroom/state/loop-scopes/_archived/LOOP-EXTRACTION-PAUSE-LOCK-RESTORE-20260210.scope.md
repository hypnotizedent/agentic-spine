# LOOP-EXTRACTION-PAUSE-LOCK-RESTORE-20260210

> **Status:** CLOSED
> **Owner:** @ronny
> **Created:** 2026-02-10
> **Severity:** high

## Problem

`spine.verify` is failing D33 because `ops/bindings/extraction.mode.yaml` is set to `mode: active`, but the gate requires `mode: paused` and a non-null `until_utc`.

## Scope

- Restore `ops/bindings/extraction.mode.yaml` to a D33-compliant shape (`mode: paused`, `until_utc` present).
- Re-run `./bin/ops cap run spine.verify` to prove D33 is PASS.

## Acceptance

- `spine.verify` PASS with D33 PASS.
- Receipt path recorded in this scope doc.

## Evidence

- Receipt (`spine.verify` PASS, includes D33 PASS): `receipts/sessions/RCAP-20260210-084227__spine.verify__Rfspd55866/receipt.md`
