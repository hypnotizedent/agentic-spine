---
loop_id: LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: media
priority: high
horizon: later
execution_readiness: blocked
objective: Define a canonical, execution-ready migration connector from shop media stack to home target topology (planning-only, no runtime mutation)
blocked_by:
  - "Home maintenance window not scheduled"
  - "Home target topology not finalized in canonical contract"
  - "Path/status parity gaps from forensic trace remain open"
---

# Loop Scope: LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303

## Objective

Create the full planning connector needed to execute media migration from shop
(VM 209/210 canonical runtime) to home target infrastructure without ad-hoc
fixes or memory-driven decisions.

This loop is planning-only and non-mutating.

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303`

## Scope

In:
- Migration transaction design (preflight, cutover, rollback, post-verify)
- Contract parity mapping (service registry, relocation plan, media bindings)
- Home target readiness matrix and blockers
- Execution packet template for future mutation wave

Out:
- Live container/path edits
- DNS/routing cutovers
- Runtime compose/deploy mutations

## Phases

1. **C0 - Baseline ingestion**
   Import the forensic outputs from
   `LOOP-MEDIA-STACK-DISCONNECT-CANONICAL-TRACE-20260303`.
2. **C1 - Topology declaration**
   Declare authoritative target topology for home runtime and cross-site role split.
3. **C2 - Contract parity packet**
   Build service/path/status parity matrix across:
   `infra.relocation.plan.yaml`, `media.services.yaml`, `SERVICE_REGISTRY.yaml`.
4. **C3 - Cutover transaction model**
   Define migration packet contract with:
   preflight checks, cutover sequence, rollback branch, post-cutover verification.
5. **C4 - Operator-ready execution handoff**
   Produce a morning execution packet for a worker/orchestrator terminal.

## Success Criteria

- Shop-to-home migration is represented as a transactional packet, not ad-hoc notes.
- Required parity surfaces are mapped with no unresolved authority ambiguity.
- Blockers are explicit, gap-linked, and review-dated.
- Future execution loop can start without rediscovery work.

## Definition Of Done

- Scope artifact and connector report are committed.
- Connector gaps are registered and parented to this loop.
- Loop remains planned/blocked until operator green-lights execution.
