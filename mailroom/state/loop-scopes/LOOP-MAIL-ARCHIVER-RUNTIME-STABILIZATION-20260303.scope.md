---
loop_id: LOOP-MAIL-ARCHIVER-RUNTIME-STABILIZATION-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: communications
priority: high
horizon: now
execution_readiness: runnable
execution_mode: single_worker
next_review: "2026-03-10"
objective: Resolve mail-archiver stabilization gaps (continuation packet, overlap assets, DB backup) in a single governed execution wave.
---

# Loop Scope: LOOP-MAIL-ARCHIVER-RUNTIME-STABILIZATION-20260303

## Objective

Resolve three mail-archiver stabilization gaps that were blocked by runtime access in the parent post-sync stabilization loop. Deliver: a normalized continuation packet, restored overlap cleanup capabilities and contracts, and a deployed pg_dump backup job with backup inventory registration.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAIL-ARCHIVER-RUNTIME-STABILIZATION-20260303`

## Phases

- Step 1: Author continuation packet for post-sync mail-archiver lanes
- Step 2: Restore missing overlap cleanup capabilities and alias boundary contract
- Step 3: Author and register DB backup capability with inventory integration
- Step 4: Close resolved gaps with evidence

## Success Criteria

- Continuation packet exists with deterministic preconditions, ownership, and handoff path.
- Missing overlap cleanup capability scripts and alias boundary contract are restored.
- DB backup capability is registered with cron template and inventory reference.
- All three target gaps (1363, 1364, 1368) are closed with evidence.

## Definition Of Done

- All target artifacts committed and verified.
- Gaps closed with regression evidence where required.
- verify.run fast passes.

## Linked Gaps

- GAP-OP-1363 -- Continuation packet normalization (RESOLVED: packet + D335 gate)
- GAP-OP-1364 -- Missing overlap cleanup governed assets (RESOLVED: 2 capabilities + alias boundary contract)
- GAP-OP-1368 -- DB backup job registration and inventory (RESOLVED: backup status capability + cron template + contract update)
