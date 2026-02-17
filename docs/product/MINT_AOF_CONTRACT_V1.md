---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: mint-aof-contract-v1
parent_loop: LOOP-MINT-AOF-BASELINE-V1-20260217
---

# Mint AOF Contract v1

## Purpose

Define a single baseline authority for Mint UI, API, DB, integration, agent/MCP flow, and delivery constraints.

## No-Regression Constraint

Current `/Users/ronnyworks/code/mint-modules` runtime behavior is protected. Baseline rollout in this wave is documentation and template scaffolding only.

## 1) UI Contract

Applies to admin, customer, and production portals.

1. Shared design tokens, spacing, typography, and color semantics.
2. Shared page shell grammar (navigation, command surfaces, status and errors).
3. Shared component state model (`loading`, `empty`, `error`, `success`).
4. Shared accessibility baseline (keyboard-first, focus order, contrast).

## 2) API Contract

1. Canonical response envelope for success and error.
2. Canonical auth + permission vocabulary.
3. Idempotency required for mutating writes.
4. Canonical pagination/filter/sort contract.
5. OpenAPI is authority for endpoint definitions.

## 3) DB Contract

1. Canonical naming for tables, columns, constraints, and indexes.
2. Explicit module ownership per schema segment.
3. Migration lifecycle: generate, review, apply, receipt evidence.
4. Controlled backfill and rollback protocol; no ad-hoc production SQL.

## 4) Integration Contract

1. Module boundaries are explicit and versioned.
2. Correlation IDs propagate across service boundaries.
3. Retry, timeout, and dead-letter semantics are standardized.
4. Cross-module contracts must be documented before implementation.

## 5) Agent/MCP Contract

Canonical operator flow:

`email -> quote -> notify -> payment request -> art upload -> status update`

Each step must define:

1. Input contract.
2. Capability/API invocation.
3. Output artifact and receipt.
4. Failure handling and recovery action.

## 6) Delivery Contract

1. Secrets naming and project/path routing are canonical.
2. Compose/env matrix is defined once and reused.
3. Environment targets (`dev`, `staging`, `prod`) share contract shape.
4. Baseline adoption cannot introduce runtime/deploy mutation in this wave.
