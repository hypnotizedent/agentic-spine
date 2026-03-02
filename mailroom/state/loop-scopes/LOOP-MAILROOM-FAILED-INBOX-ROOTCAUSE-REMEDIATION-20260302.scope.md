---
loop_id: LOOP-MAILROOM-FAILED-INBOX-ROOTCAUSE-REMEDIATION-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: mailroom
priority: high
horizon: now
execution_readiness: runnable
objective: Find and resolve root cause for failed inbox/provider balance failures; normalize requeue/archive flow.
---

# Loop Scope: LOOP-MAILROOM-FAILED-INBOX-ROOTCAUSE-REMEDIATION-20260302

## Objective

Find and resolve root cause for failed inbox/provider balance failures; normalize requeue/archive flow.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAILROOM-FAILED-INBOX-ROOTCAUSE-REMEDIATION-20260302`

## Phases
- W0:  Capture failed inbox classification + provider error taxonomy
- W1:  Fix provider/package/route failure source
- W2:  Requeue or archive failed items with receipts

## Success Criteria
- Failed inbox anomalies reduced to zero or explicitly parked with owned gap refs
- spine.control.tick anomaly count no longer includes failed inbox burst

## Definition Of Done
- Run verify.run -- fast PASS
- Run spine.control.tick and mailroom queue evidence captured
