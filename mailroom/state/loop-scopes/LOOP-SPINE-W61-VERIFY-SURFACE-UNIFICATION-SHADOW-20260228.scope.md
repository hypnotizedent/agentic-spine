---
loop_id: LOOP-SPINE-W61-VERIFY-SURFACE-UNIFICATION-SHADOW-20260228
created: 2026-02-28
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Deliver one canonical verify command surface in shadow mode with profile semantics (fast/domain/release), failure-class outputs, and parity evidence against existing verify paths.
---

# Loop Scope: LOOP-SPINE-W61-VERIFY-SURFACE-UNIFICATION-SHADOW-20260228

## Objective

Deliver one canonical verify command surface in shadow mode with profile semantics (fast/domain/release), failure-class outputs, and parity evidence against existing verify paths.

## Steps
- Step 1: classify gate portfolio and define profile mappings
- Step 2: implement verify wrapper in shadow mode
- Step 3: collect parity/failure-class evidence and decide cutover readiness

## Success Criteria
- verify wrapper produces no unresolved blocking diffs in shadow parity report
- failure_class emitted for blocking failures

## Definition Of Done
- W61 verify shadow parity report committed
- W61 failure-class baseline report committed
