---
loop_id: LOOP-SPINE-COMMS-QUEUE-RELIABILITY-V5-20260222
created: 2026-02-22
status: closed
owner: "@ronny"
scope: communications
priority: medium
severity: medium
objective: Surface communications queue + escalation health in watcher and status surfaces for incident visibility without manual deep checks.
---

# Loop Scope: Queue Reliability V5 - Watcher/Status Integration

## Objective

Expose communications queue + escalation health directly in default operator status/watcher surfaces so incident handling is visible without manual deep checks.

## Deliverables

- A) New capability: `communications.alerts.runtime.status` (read-only, auto)
- B) Embed rollup in `spine.watcher.status` and `./bin/ops status` output
- C) Add comms queue incident signal to `spine.control.tick` (observability-only)
- D) Raycast launcher action for runtime status
- E) Update communications agent contract with Watcher First Triage runbook
- F) Full verification pass

## Safety Boundaries (unchanged)

- `alerting.dispatch` = auto intent-only
- `communications.alerts.flush` = manual
- `communications.alerts.queue.escalate` = manual
