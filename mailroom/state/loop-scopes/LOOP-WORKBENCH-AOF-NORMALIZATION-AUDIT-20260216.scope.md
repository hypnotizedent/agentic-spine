---
loop_id: LOOP-WORKBENCH-AOF-NORMALIZATION-AUDIT-20260216
created: 2026-02-16
status: active
owner: "@ronny"
scope: workbench
objective: Produce a canonical normalization audit across workbench and convert results into a strict AOF implementation plan.
---

## Audit Lanes

1. Lane A: baseline structure + surface consistency
2. Lane B: runtime/deploy/container/compose normalization
3. Lane C: secrets/governance/injection normalization

## Deliverable Contract

- All lanes write findings to `/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/`.
- Findings must include absolute file paths + line references.
- No fixes in this loop; audit only.
