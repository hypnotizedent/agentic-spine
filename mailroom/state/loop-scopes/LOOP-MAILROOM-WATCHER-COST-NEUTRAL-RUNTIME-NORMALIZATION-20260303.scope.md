---
loop_id: LOOP-MAILROOM-WATCHER-COST-NEUTRAL-RUNTIME-NORMALIZATION-20260303
created: 2026-03-03
status: active
owner: "@ronny"
scope: mailroom
priority: high
horizon: now
execution_readiness: runnable
objective: Eliminate watcher billing lock-in and mailroom runtime disconnects by aligning provider policy, queue authority paths, token source, and launchd/runtime parity.
---

# Loop Scope: LOOP-MAILROOM-WATCHER-COST-NEUTRAL-RUNTIME-NORMALIZATION-20260303

## Objective

Eliminate watcher billing lock-in and mailroom runtime disconnects by aligning provider policy, queue authority paths, token source, and launchd/runtime parity.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAILROOM-WATCHER-COST-NEUTRAL-RUNTIME-NORMALIZATION-20260303`

## Phases
- W0:  establish evidence-backed baseline and root-cause map
- W1:  add cost-neutral watcher provider lane (local or zero-LLM dispatch)
- W2:  normalize enqueue/worker/status authority paths to runtime contract
- W3:  normalize launchd env and token-source authority with regression gates
- W4:  verify, receipt, and close with rollback-safe defaults

## Success Criteria
- Watcher processing continues when paid API balance is depleted by using approved fallback lane.
- Bridge enqueue, watcher status, and task worker all resolve consistent authority paths.
- Single canonical token-source contract is enforced and verifiable.
- LaunchAgent templates and live plists pass parity locks.

## Definition Of Done
- Loop has linked gaps with concrete evidence and owner surfaces.
- Fast verify and touched domain verifies pass with run keys recorded.
- Rollback path documented for provider lane and launchd environment changes.

## Progress Checkpoint
- W2 in progress: bridge/watcher/status surfaces now resolve runtime paths via `ops/lib/runtime-paths.sh`.
- W3 in progress: launchd env parity lock (`D328`) added to prevent runtime-root/token-source drift recurrence.
- W1/W3 in progress: watcher provider policy normalized to local-first + explicit paid override with circuit-breaker parking lock (`D329`).
- Remaining: explicit gap closure receipts + final loop closeout once fallback lane is validated in production.
