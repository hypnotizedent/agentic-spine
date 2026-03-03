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

## Linked Gaps

- GAP-OP-1402 — transaction packet delivered (docs/planning/MEDIA-SHOP-HOME-MIGRATION-TRANSACTION-PACKET.md)
- GAP-OP-1403 — OPEN: home target readiness baseline (blocked_by_ronny_arch_decision + blocked_by_ronny_on_site)
- GAP-OP-1404 — skeleton delivered (ops/bindings/media.path.authority.contract.yaml); needs runtime verification to close
- GAP-OP-1405 — skeleton delivered (ops/bindings/media.availability.progression.contract.yaml); needs runtime observation to close
- GAP-OP-1406 — lineage checkpoint delivered (docs/planning/MEDIA-MIGRATION-LINEAGE-CHECKPOINT.md)

## Artifacts Delivered (2026-03-03)

| Artifact | Path | Gap |
|----------|------|-----|
| Migration transaction packet | docs/planning/MEDIA-SHOP-HOME-MIGRATION-TRANSACTION-PACKET.md | GAP-OP-1402 |
| Lineage checkpoint | docs/planning/MEDIA-MIGRATION-LINEAGE-CHECKPOINT.md | GAP-OP-1406 |
| Path authority contract (skeleton) | ops/bindings/media.path.authority.contract.yaml | GAP-OP-1404 |
| Availability progression contract (skeleton) | ops/bindings/media.availability.progression.contract.yaml | GAP-OP-1405 |

## Gap Blocker Evidence (2026-03-03)

| Gap | Blocker Class | Detail |
|-----|---------------|--------|
| GAP-OP-1402 | closeable | Transaction packet artifact delivered with preflight/cutover/rollback/post-verify sections |
| GAP-OP-1403 | blocked_by_ronny_on_site + blocked_by_ronny_arch_decision | Home target topology not declared; requires home maintenance window + storage/network capacity assessment |
| GAP-OP-1404 | blocked_by_runtime_access | Skeleton delivered but TBD fields require docker inspect + app API queries on live VMs |
| GAP-OP-1405 | blocked_by_runtime_access | Skeleton delivered but sync handshake timing needs runtime observation |
| GAP-OP-1406 | closeable | Lineage checkpoint artifact delivered with 5 historical failure patterns + mandatory pre-execution checklist |
