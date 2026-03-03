---
loop_id: LOOP-MAIL-ARCHIVER-POST-SYNC-STABILIZATION-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: communications
priority: high
horizon: later
execution_readiness: blocked
next_review: "2026-03-09"
objective: Consolidate post-sync mail-archiver next-best-leverage work into one canonical execution lane after live ingest stabilizes.
blocked_by: "Active live sync/import window on VM214; execute only after stable checkpoints are captured."
---

# Loop Scope: LOOP-MAIL-ARCHIVER-POST-SYNC-STABILIZATION-20260302

## Objective

Consolidate post-sync mail-archiver next-best-leverage work into one canonical execution lane after live ingest stabilizes.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAIL-ARCHIVER-POST-SYNC-STABILIZATION-20260302`

## Phases
- W1:  Lifecycle normalization and parent-link reconciliation
- W2:  Overlap cleanup tooling restoration and contract parity
- W3:  Domain/sync truth normalization for Microsoft lane semantics
- W4:  Post-sync execution packet and closeout readiness bundle

## Success Criteria
- One canonical post-sync lane exists for mail-archiver continuation work.
- Closed-loop/blocked-loop contradictions are reconciled with explicit status truth.
- Overlap cleanup references point to existing governed capabilities/contracts.
- Account linkage truth for provider live-sync semantics is internally consistent.
- Next-best-leverage packet is ready for a single execution terminal.

## Definition Of Done
- Scope artifacts updated and committed.
- All linked gaps attached to this loop with deterministic acceptance criteria.
- No runtime/service mutations performed in this loop.

## Linked Gaps
- GAP-OP-1362 — CLOSED: EWS loop metadata contradiction fixed (execution_readiness removed from closed loop)
- GAP-OP-1363 — OPEN: structural fix committed (b5555ac) but high-severity close requires regression_lock_id gate (none exists yet)
- GAP-OP-1364 — OPEN: overlap cleanup missing governed assets (blocked_by_runtime_access)
- GAP-OP-1365 — CLOSED: microsoft live_sync_ready updated to true (Graph API active)
- GAP-OP-1366 — OPEN: overlap cleanup closure semantics need reconciliation (blocked_by_ronny_arch_decision)
- GAP-OP-1367 — OPEN: email classification/retention contract needs architecture decision (blocked_by_ronny_arch_decision)
- GAP-OP-1368 — OPEN: 126GB PostgreSQL DB backup not governed (blocked_by_runtime_access)
- GAP-OP-1369 — OPEN: email domain boundary contract needs architecture decision (blocked_by_ronny_arch_decision)

## Gap Blocker Evidence (2026-03-03)

| Gap | Blocker Class | Detail |
|-----|---------------|--------|
| GAP-OP-1363 | blocked_by_runtime_access | Structural fix committed (b5555ac: loop container with preconditions, ownership, handoff); gap remains open because high-severity close requires regression_lock_id gate (no communications domain gate exists yet) |
| GAP-OP-1364 | blocked_by_runtime_access | Missing capabilities (communications.mailarchiver.overlap.plan, .import.eml.remote) and contract (mail.archiver.alias.boundary.contract.yaml) must be authored or reconciled |
| GAP-OP-1366 | blocked_by_ronny_arch_decision | GAP-OP-1002 closed overlap cleanup while LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226 remains planned — reconciliation requires decision on whether overlap work is truly done or deferred |
| GAP-OP-1367 | blocked_by_ronny_arch_decision | No retention value classification, junk/unsubscribe bucketing, or pruning rules defined — requires domain owner decision |
| GAP-OP-1368 | blocked_by_runtime_access | pg_dump job for 126GB MailArchiver PostgreSQL needs VM214 runtime access and backup inventory integration |
| GAP-OP-1367 | blocked_by_ronny_arch_decision | Draft contract authored: `mail.archiver.email.classification.contract.yaml` — 6-tier taxonomy with routing/pruning rules. Awaits Ronny review to promote from draft to authoritative. |
| GAP-OP-1368 | blocked_by_runtime_access | pg_dump job for 126GB MailArchiver PostgreSQL needs VM214 runtime access and backup inventory integration |
| GAP-OP-1369 | blocked_by_ronny_arch_decision | Draft contract authored: `mail.archiver.domain.boundary.contract.yaml` — 4 domain classes with per-account assignment. Awaits Ronny review to promote from draft to authoritative. |

## Lane A Deliverables (2026-03-03)

Contracts authored during governance-only burndown (no VM214 runtime access).

| # | Deliverable | File | Status |
|---|-------------|------|--------|
| D1 | Email Classification Contract | `ops/bindings/mail.archiver.email.classification.contract.yaml` | draft (awaits arch review) |
| D2 | Domain Boundary Contract | `ops/bindings/mail.archiver.domain.boundary.contract.yaml` | draft (awaits arch review) |
| D3 | Overlap Cleanup Reconciliation | Analysis below | complete |

### D3: Overlap Cleanup Reconciliation Analysis

GAP-OP-1002 was closed with `governance_debt_archived` — a deferral marker, not completion.
LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226 remains `planned` with TODO execution steps.
3 of 4 pre-staged capability assets are missing from disk. 1,390 strict dedupe candidates remain uncleaned.

**Recommended path (for Ronny)**: Absorb remaining overlap work into this stabilization loop.
Mark LOOP-MAIL-ARCHIVER-OVERLAP-CLEANUP-20260226 as `superseded`. Then close GAP-OP-1366.
