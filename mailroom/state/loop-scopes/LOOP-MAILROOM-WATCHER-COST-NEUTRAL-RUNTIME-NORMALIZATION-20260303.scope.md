---
loop_id: LOOP-MAILROOM-WATCHER-COST-NEUTRAL-RUNTIME-NORMALIZATION-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: mailroom
priority: high
horizon: now
execution_readiness: complete
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
- W1 complete: watcher provider policy normalized to local-first with explicit paid override + circuit-breaker parking path (`D74`, `D329`).
- W2 complete: enqueue/watcher/status/bridge authority paths normalized to runtime contract model (`D328`).
- W3 complete: launchd env and token-source parity normalized and regression locked (`D328`; runtime token authority enforced).
- Verify evidence: `CAP-20260302-235109__verify.run__Rrnt050332`, `CAP-20260302-235241__mailroom.bridge.status__Rxkqf35623`, `CAP-20260302-235241__spine.watcher.status__Ro9al35620`.
- Gap closure: `GAP-OP-1370..1375` fixed; remaining self-hosted inference contract work reparented to `LOOP-MAILROOM-WATCHER-SELF-HOSTED-INFERENCE-CONTRACT-20260303` (`GAP-OP-1376`).
