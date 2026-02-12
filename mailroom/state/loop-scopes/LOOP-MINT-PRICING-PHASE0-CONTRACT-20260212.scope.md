---
loop_id: LOOP-MINT-PRICING-PHASE0-CONTRACT-20260212
status: open
owner: "@ronny"
apply_owner: claude
opened: 2026-02-12
scope: Lock pricing module API contract, port, health spec, Dockerfile, secrets namespace
---

# LOOP-MINT-PRICING-PHASE0-CONTRACT-20260212

## Goal

Define the canonical contract for the pricing module (migrating from job-estimator)
and lock all Phase 0 artifacts: API boundary, health spec, Dockerfile, compose,
deprecation answer, and secrets namespace.

## Hard Constraints

1. No runtime mutations (no docker, no vm, no dns/cloudflare, no infisical writes).
2. No application code (src/) — contract/planning/Dockerfile only.
3. One commit per repo, then close loop.

## Deliverables

1. `mint-modules/docs/ARCHITECTURE/PRICING_MODULE_CONTRACT.md` — API boundary, health spec, port, deprecation answer
2. `mint-modules/pricing/Dockerfile` — multi-stage build, port 3700
3. `mint-modules/pricing/docker-compose.yml` — module compose with health check
4. `agentic-spine/ops/bindings/secrets.namespace.policy.yaml` — pricing namespace added
5. This scope file

## Phases

- P0: Baseline verify + gaps + authority status
- P1: Create contract doc + Dockerfile + compose + secrets namespace + scope file
- P2: Recert (spine.verify + tests)
- P3: Push both repos
- P4: Final report
