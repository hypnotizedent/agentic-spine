---
loop_id: LOOP-MINT-REMAINING-MODULES-PLAN-QUEUE-20260212
status: open
owner: "@ronny"
apply_owner: claude
opened: 2026-02-12
scope: Turn audit findings into executable proposal queue for shipping/pricing/suppliers
---

# LOOP-MINT-REMAINING-MODULES-PLAN-QUEUE-20260212

## Goal

Turn legacy audit findings into an executable proposal queue for shipping, pricing,
and suppliers modules — fully aligned to the fresh-slate VM model (mint-data 212,
mint-apps 213) — with zero runtime changes.

## Hard Constraints

1. No infra/runtime mutations (no docker, no vm, no dns/cloudflare, no infisical writes).
2. No code changes in module services.
3. Docs/planning/governance updates only.
4. One proposal pack, then close loop.

## Deliverables

1. `mint-modules/docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md` — ranked loops for shipping, pricing, suppliers
2. `mint-modules/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md` — current state vs target state
3. `mint-modules/docs/DECISIONS/README.md` — supersession notes mapping old audit assumptions to ADR truth
4. Proposal entries for 4 planning-only loops (no apply)

## Phases

- P0: Baseline verify + gaps + authority status
- P1: Build canonical planning artifacts
- P2: Generate proposal queue (planning-only)
- P3: Recert + close
