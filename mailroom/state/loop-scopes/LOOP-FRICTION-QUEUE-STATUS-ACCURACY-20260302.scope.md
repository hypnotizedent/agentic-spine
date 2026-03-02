---
loop_id: LOOP-FRICTION-QUEUE-STATUS-ACCURACY-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: friction
priority: medium
horizon: now
execution_readiness: runnable
objective: "Make friction queue counters self-verifying with invariant assertions and regression check"
---

# Loop Scope: LOOP-FRICTION-QUEUE-STATUS-ACCURACY-20260302

## Objective

Make friction queue counters self-verifying with invariant assertions and regression check

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-QUEUE-STATUS-ACCURACY-20260302`

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

- Root cause: counters were already reading live NDJSON (no caching). Observed drift was from failed reconcile (argparse -- separator issue) not updating queue file.
- Added invariant assertion: total == queued + filed + matched (fails visibly on violation)
- Added --check flag for regression testing (exits non-zero on invariant violation)
- Added unknown_status tracking for unrecognized status values
- Added invariant_ok field to JSON output
- verify.run fast: 10/10 PASS
- friction.queue.status --check: PASS
