---
loop_id: LOOP-MINT-SUPPLIERS-PHASE0-CONTRACT-20260212
status: open
owner: "@ronny"
apply_owner: claude
opened: 2026-02-12
scope: Lock suppliers module API contract, table ownership, sync strategy, secrets namespace
---

# LOOP-MINT-SUPPLIERS-PHASE0-CONTRACT-20260212

## Goal

Define the canonical contract for the suppliers module (migrating from legacy
apps/api/suppliers/ + scripts/suppliers/) and lock all Phase 0 artifacts.

## Hard Constraints

1. No runtime mutations (no docker, no vm, no dns/cloudflare, no infisical writes).
2. No application code (src/) — contract/planning/Dockerfile only.
3. One commit per repo, then close loop.

## Deliverables

1. `mint-modules/docs/ARCHITECTURE/SUPPLIERS_MODULE_CONTRACT.md` — full contract
2. `mint-modules/suppliers/Dockerfile` — query API container
3. `mint-modules/suppliers/docker-compose.yml` — module compose
4. `agentic-spine/ops/bindings/secrets.namespace.policy.yaml` — suppliers namespace
5. `agentic-spine/mailroom/state/loop-scopes/` — this scope file
6. MODULE_RUNTIME_BOUNDARY.md updated with suppliers entry

## Phases

- P0: Baseline verify + gaps + authority status
- P1: Create all deliverables
- P2: Recert
- P3: Push both repos
- P4: Close loop
