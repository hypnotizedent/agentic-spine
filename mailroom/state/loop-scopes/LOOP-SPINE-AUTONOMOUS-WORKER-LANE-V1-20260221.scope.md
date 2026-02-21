---
loop_id: LOOP-SPINE-AUTONOMOUS-WORKER-LANE-V1-20260221
created: 2026-02-21
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Implement governed autonomous worker lane for spine.control.cycle and mailroom task consumption
---

# Loop Scope: LOOP-SPINE-AUTONOMOUS-WORKER-LANE-V1-20260221

## Objective

Implement governed autonomous worker lane for spine.control.cycle and mailroom task consumption

## Deliverables

- Added worker contract: `ops/bindings/mailroom.task.worker.contract.yaml`
- Added worker runtime surface: `ops/plugins/mailroom-bridge/bin/mailroom-task-worker`
- Registered worker lifecycle capabilities:
  - `mailroom.task.worker.start`
  - `mailroom.task.worker.stop`
  - `mailroom.task.worker.status`
  - `mailroom.task.worker.once`
- Updated capability/plugin maps and control-loop governance docs
- Added worker smoke test: `ops/plugins/mailroom-bridge/tests/test-task-worker.sh`

## Verification

- `CAP-20260220-232613__mailroom.task.worker.status__R0hmv12316`
- `CAP-20260220-232618__verify.core.run__R7ro812881`
- `CAP-20260220-232948__verify.pack.run__R45ik81517`
