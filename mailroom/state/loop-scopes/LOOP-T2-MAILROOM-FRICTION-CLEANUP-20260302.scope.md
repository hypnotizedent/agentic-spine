---
loop_id: LOOP-T2-MAILROOM-FRICTION-CLEANUP-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: t2
priority: medium
horizon: now
execution_readiness: runnable
objective: "Mailroom friction cleanup: role override ergonomics, AOF ack caching, gaps.reparent capability, D129/D136/D308 hardening"
---

# Loop Scope: LOOP-T2-MAILROOM-FRICTION-CLEANUP-20260302

## Objective

Mailroom friction cleanup: role override ergonomics, AOF ack caching, gaps.reparent capability, D129/D136/D308 hardening

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-T2-MAILROOM-FRICTION-CLEANUP-20260302`

## Phases
- Step 1: capture and classify findings
- Step 2: implement changes
- Step 3: verify and close out

## Success Criteria
- All linked gaps/proposals are captured and linked to this loop.
- Relevant verify pack(s) pass.

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.

## Resolution

- F1 (role override tax): session.role.override capability + cap.sh session cache fallback
- F2 (AOF ack friction): auto-acknowledge when session role override is active
- F3 (.gitignore ergonomics): governed comment pattern for new state surfaces
- F4 (gaps.reparent): new capability with --from-parent-loop, --to-parent-loop, --ids, --reason, --dry-run
- F5 (D129 false-positive): staged vs unstaged separation, D129_STRICT=1 for full-tree mode
- F6 (scope blind spots): D136/D308 detect unparseable scope files with open status indicators
- GAP-OP-1281: reparented from closed loop to LOOP-AGENT-FRICTION-BACKLOG-20260302
- Orphans: 1 → 0
- verify.run fast: 10/10 PASS
- verify.run domain aof: 25/28 (D122, D131, D133 pre-existing)
- Commits: c16542d, f93b4be, d6da06a
