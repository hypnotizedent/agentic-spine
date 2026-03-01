---
loop_id: LOOP-PLANNING-HORIZON-CONTROL-PLANE-20260301
created: 2026-03-01
status: closed
owner: "@ronny"
scope: planning
priority: high
horizon: now
execution_readiness: runnable
objective: Prevent rushed implementation by making now/later/future a canonical execution control plane in mailroom/runtime surfaces
---

# Loop Scope: LOOP-PLANNING-HORIZON-CONTROL-PLANE-20260301

## Objective

Prevent rushed implementation by making now/later/future a canonical execution control plane in mailroom/runtime surfaces

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-PLANNING-HORIZON-CONTROL-PLANE-20260301`

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

## W0 Baseline (2026-03-01T03:53Z)
- verify.run fast: 10/10 PASS
- verify.pack.run loop_gap: 32/33 PASS (D83 pre-existing)
- verify.route.recommend: D128,D148,D275,D285,D85 all pre-existing
- session.start: 0 open loops, 0 open gaps, 0 anomalies (excl. 1 pre-existing)
