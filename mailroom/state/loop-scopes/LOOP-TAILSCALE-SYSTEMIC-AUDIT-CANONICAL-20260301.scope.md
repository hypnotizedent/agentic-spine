---
loop_id: LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301
created: 2026-03-01
status: active
owner: "@ronny"
scope: tailscale
priority: high
horizon: now
execution_readiness: runnable
objective: Run a canonical systemic audit of Tailscale auth behavior across verify/scheduler/backup/runtime paths, isolate root causes of interactive auth popups and hangs, and define single-source policy + enforcement updates to eliminate drift between tailscale SSH and LAN paths.
---

# Loop Scope: LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301

## Objective

Run a canonical systemic audit of Tailscale auth behavior across verify/scheduler/backup/runtime paths, isolate root causes of interactive auth popups and hangs, and define single-source policy + enforcement updates to eliminate drift between tailscale SSH and LAN paths.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301`

## Phases
- W1:  Evidence capture across verify/scheduler/backup runtimes
- W2:  Root-cause mapping for auth prompts and command-path drift
- W3:  Canonical contract + gate/capability alignment
- W4:  Validation and closeout criteria

## Success Criteria
- No interactive Tailscale auth prompts during governed verify paths
- Deterministic passive/active probe policy enforced in one authority surface
- Scheduler health remains green with no auth-induced false failures

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
