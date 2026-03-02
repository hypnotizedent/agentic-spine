---
loop_id: LOOP-FRICTION-GAPS-FILE-MACOS-SED-COMPATIBILITY-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: medium
horizon: later
execution_readiness: runnable
objective: Eliminate BSD sed warning spam in gaps.file batch mode on macOS.
---

# Loop Scope: LOOP-FRICTION-GAPS-FILE-MACOS-SED-COMPATIBILITY-20260302

## Objective

Eliminate BSD sed warning spam in gaps.file batch mode on macOS.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-GAPS-FILE-MACOS-SED-COMPATIBILITY-20260302`

## Phases
- P1:  reproduce title-derivation warning path in gaps.file batch
- P2:  implement portable parser behavior for macOS/Linux
- P3:  validate clean batch filing and close linked gap

## Success Criteria
- gaps.file --batch emits no sed warnings on macOS
- batch title derivation remains deterministic

## Definition Of Done
- cross-platform shell compatibility lock added
- linked gap closed with receipts
