---
loop_id: LOOP-SPINE-W60-TRUTH-VERIFICATION-20260227-20260302
created: 2026-02-28
status: active
owner: "@ronny"
scope: spine
priority: high
parent_loop: LOOP-SPINE-W60-SUPERVISOR-CANONICAL-UPGRADE-20260227-20260302
objective: Verify recent audit claims against direct runtime/file truth and classify each with canonical action decisions.
execution_mode: foreground
---

# Loop Scope: LOOP-SPINE-W60-TRUTH-VERIFICATION-20260227-20260302

## Objective

Produce an evidence-backed truth matrix of current findings and a stale-surface matrix for untouched artifacts over seven days.

## Deliverables

- `docs/planning/W60_FINDING_TRUTH_MATRIX.md`
- `docs/planning/W60_UNTOUCHED_OVER_7_DAYS_MATRIX.md`

## Success Criteria

- Every verified claim has severity and one decision (`fix_now`, `lock_only`, `archive`, `tombstone`, `gap`).
- Evidence commands are recorded for each finding row.

## Definition Of Done

- Matrices committed with deterministic, reproducible evidence paths.
