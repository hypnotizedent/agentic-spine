---
loop_id: LOOP-SPINE-SELF-HEALING-E2E-20260301
created: 2026-03-01
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Implement spine self-healing end to end (recovery dispatch, gap auto-close, uptime kuma activation) with governed receipts and merge-back.
---

# Loop Scope: LOOP-SPINE-SELF-HEALING-E2E-20260301

## Objective

Implement spine self-healing end to end (recovery dispatch, gap auto-close, uptime kuma activation) with governed receipts and merge-back.

## Phases
- Step 1: recovery engine + verify/alerting integration
- Step 2: gap auto-close + pass streak tracking
- Step 3: uptime kuma validation/sync + observability checks
- Step 4: governance normalization + verification + mergeback

## Success Criteria
- Recovery dispatch executes automatically for mapped deterministic/freshness failures.
- Verify-response-loop gaps can auto-close safely on stable recovery signals.
- Uptime Kuma monitor state is synchronized from services.health and independently alert-capable.
- All required gates/contracts pass and artifacts are normalized without breaking last-48h governance changes.

## Definition Of Done
- All new/modified capabilities registered in ops/capabilities.yaml and ops/bindings/capability_map.yaml with passing D67.
- Gate additions and generated entry-surface metadata updated and passing D285.
- Changes land on a dedicated loop branch, verified, merged/cherry-picked back to main, pushed, and branch/worktree cleaned.
