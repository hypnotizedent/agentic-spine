---
loop_id: LOOP-FRICTION-ROLE-PRECOMMIT-EXECUTION-NORMALIZATION-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: friction
priority: medium
horizon: now
execution_readiness: runnable
objective: Eliminate operator friction in role/session/pre-commit flow: implement session-override-aware pre-commit, fix terminal role precedence, resolve write-scope and docs.projection.sync friction. Close GAP-OP-1299/1300/1301/1302/1304/1309/1336/1338.
---

# Loop Scope: LOOP-FRICTION-ROLE-PRECOMMIT-EXECUTION-NORMALIZATION-20260303

## Objective

Eliminate operator friction in role/session/pre-commit flow: implement session-override-aware pre-commit, fix terminal role precedence, resolve write-scope and docs.projection.sync friction. Close GAP-OP-1299/1300/1301/1302/1304/1309/1336/1338.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-ROLE-PRECOMMIT-EXECUTION-NORMALIZATION-20260303`

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
