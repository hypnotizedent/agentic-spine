---
loop_id: LOOP-SPINE-W60-SUPERVISOR-CANONICAL-UPGRADE-20260227-20260302
created: 2026-02-28
status: active
owner: "@ronny"
scope: spine
priority: high
objective: Deliver a canonical multi-repo supervisor wave that verifies truth, executes non-destructive cleanup, and installs regression locks with receipted verification.
execution_mode: foreground
---

# Loop Scope: LOOP-SPINE-W60-SUPERVISOR-CANONICAL-UPGRADE-20260227-20260302

## Objective

Deliver a canonical end-to-end spine upgrade across `agentic-spine`, `workbench`, and `mint-modules` under a sole-writer supervisor model.

## Subloops

- LOOP-SPINE-W60-TRUTH-VERIFICATION-20260227-20260302
- LOOP-SPINE-W60-CLEANUP-EXECUTION-20260227-20260302
- LOOP-SPINE-W60-REGRESSION-LOCKS-20260227-20260302

## Constraints

- Sole writer terminal: `SPINE-CONTROL-01`.
- Protected lanes stay untouched: `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`, `GAP-OP-973`, active EWS import lanes, active MD1400 rsync lanes.
- No VM/infra runtime mutation in this wave.
- Cleanup lifecycle is strict: `report-only -> archive-only -> delete(token-gated)`.
- No destructive delete/prune without `RELEASE_MAIN_CLEANUP_WINDOW`.
- Every phase closes with committed receipts and clean git state.

## Steps

- Step 1: precheck, isolation, and baseline receipts
- Step 2: exhaustive truth verification matrixes
- Step 3: canonical cleanup execution (non-destructive)
- Step 4: regression locks by recurring issue class
- Step 5: required verification suites and certification
- Step 6: loop/gap reconciliation and orphan elimination
- Step 7: FF-safe promotion and remote parity attestation

## Success Criteria

- All confirmed findings are fixed with locks or governed as explicit gaps with owner/due/evidence.
- Cleanup lifecycle policy is enforced with no tokenless deletion.
- Mainline parity is proven for all touched repos/remotes.
- Final supervisor receipts provide run keys, SHAs, acceptance matrix, and attestations.

## Definition Of Done

- All phase artifacts under `docs/planning/` are committed and linked.
- Required verifies are receipted with run keys.
- `loops.status` and `gaps.status` reconcile with no orphaned references.
- Final promotion/parity receipts and zero-status report are committed.
