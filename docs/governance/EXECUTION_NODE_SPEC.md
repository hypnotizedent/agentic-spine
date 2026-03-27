---
status: draft
owner: "@ronny"
created_at: "2026-03-24"
scope: v3-execution-node-spec
node_id: 6
related_arch: docs/governance/FINAL_SURFACES_CLOSURE_BRIEF_20260326.md
---

# Execution Node — V3 Node 6/7

## Role
The execution node runs governed capability work. It receives task envelopes
from the scheduler, executes them in sandboxed environments, and emits
EXEC_RECEIPTs with run keys.

## Host
VM 207 (ai-consolidation) — shared with broker mirror, translator, and
other worker containers.

## Responsibilities
| Role | Description |
|------|-------------|
| Task execution | Run capability commands from task envelopes |
| Receipt emission | Emit EXEC_RECEIPT per orchestration.exec_receipt.schema.json |
| Sandbox isolation | Each task runs in isolated context (container or subprocess) |
| Resource gating | Respect CPU/memory budgets per task envelope |

## Dependencies
- Scheduler (node 3) for task dispatch
- Broker (node 1) for state reads
- State authority (node 2) for gap/loop updates
- Task envelope spec (docs/contracts/TASK_ENVELOPE_SPEC.md)

## Containers
- `spine-executor`: Primary execution runtime
- Shares VM 207 with broker-mirror, translator, watcher, verifier

## Phase
- Phase 1: Manual task dispatch via terminal prompts (CURRENT)
- Phase 2: Scheduler-driven dispatch via task envelopes
- Phase 3: Auto-scaling with resource-aware scheduling

## Open Items
- Task envelope integration (scaffolded, needs wiring)
- Model adapter integration (scaffolded, needs wiring)
- Resource budget enforcement
- Concurrent task limits
