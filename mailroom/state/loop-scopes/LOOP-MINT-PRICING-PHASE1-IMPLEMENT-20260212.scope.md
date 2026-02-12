---
loop_id: LOOP-MINT-PRICING-PHASE1-IMPLEMENT-20260212
status: open
owner: "@ronny"
apply_owner: claude
opened: 2026-02-12
scope: Implement pricing module Phase 1 — scaffold, types, endpoints, tests
---

# LOOP-MINT-PRICING-PHASE1-IMPLEMENT-20260212

## Goal

Implement the pricing module scaffold with health endpoint, pricing calculation
endpoint, request/response types, and test coverage. Phase 1 of the pricing
module migration from job-estimator.

## Hard Constraints

1. No-clash mode: Terminal C commits to main, workers commit to worker/* branches.
2. No legacy runtime dependency on job-estimator.
3. Scope: pricing module only (no cross-module changes).

## Deliverables

1. Pricing types/constants/contract (Worker D)
2. Service implementation: /health, /metrics, POST /api/v1/price (Worker E)
3. Test suite + hardening (Worker F)

## Phases

- P0: Baseline verify + gaps + authority status
- P1: Dispatch workers D, E, F sequentially
- P2: Cherry-pick D -> E -> F onto main
- P3: Recert (typecheck + tests all modules + spine.verify)
- P4: Close loop with receipts
