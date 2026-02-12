---
loop_id: LOOP-MINT-SHIPPING-PHASE0-CONTRACT-20260212
status: closed
closed: 2026-02-12
owner: "@ronny"
apply_owner: claude
opened: 2026-02-12
scope: Lock shipping module API contract, table ownership, auth replacement, secrets namespace
---

# LOOP-MINT-SHIPPING-PHASE0-CONTRACT-20260212

## Goal

Define the canonical contract for the shipping module (migrating from legacy
routes/shipping.cjs + apps/shipping/) and lock all Phase 0 artifacts.

## Hard Constraints

1. No runtime mutations (no docker, no vm, no dns/cloudflare, no infisical writes).
2. No application code (src/) — contract/planning/Dockerfile only.
3. One commit per repo, then close loop.

## Deliverables

1. `mint-modules/docs/ARCHITECTURE/SHIPPING_MODULE_CONTRACT.md` — full contract
2. `mint-modules/shipping/Dockerfile` — container
3. `mint-modules/shipping/docker-compose.yml` — module compose
4. `agentic-spine/ops/bindings/secrets.namespace.policy.yaml` — shipping namespace
5. `agentic-spine/mailroom/state/loop-scopes/` — this scope file
6. MODULE_RUNTIME_BOUNDARY.md updated with shipping entry

## P0 Receipts

- spine.verify: CAP-20260212-132433__spine.verify__Rahnd80473
- gaps.status: CAP-20260212-132502__gaps.status__Rot9d90553
- authority.project.status: CAP-20260212-132503__authority.project.status__R9ls490612
