# STUB - Auto-Apply Enable Blocked

Date: 2026-03-05 (UTC)  
Wave: `WAVE-COORDINATOR-MAINLINE-ENFORCEMENT-AND-CLOSEOUT-AUTONOMY-20260305`

## Decision

- `auto_apply.enabled` remains `false` in `ops/bindings/nightly.closeout.contract.yaml`.
- Block reason: safe threshold not met (`auto_apply_safe=false` from latest dry-run).

## Residual blockers (latest dry-run)

Source: `receipts/nightly-closeout/NIGHTLY-CLOSEOUT-20260305T074105Z-19413/summary.env`

- `held_local_branches=19`
- `held_worktrees=14`
- `held_remote_origin=27`
- `held_remote_github=27`
- `branch_candidates=0`
- `remote_origin_candidates=0`
- `remote_github_candidates=0`
- `auto_apply_safe=false`

## Exact next commands

```bash
# Reclassify held sets with fresh refs
OPS_WORKTREE_IDENTITY=WAVE-COORDINATOR-MAINLINE-ENFORCEMENT-AND-CLOSEOUT-AUTONOMY-20260305 \
SPINE_ROLE_POLICY_OVERRIDE_REF=WAVE-COORDINATOR-MAINLINE-ENFORCEMENT-AND-CLOSEOUT-AUTONOMY-20260305 \
SPINE_ROLE_POLICY_OVERRIDE_REASON='held triage continuation' \
./bin/ops cap run nightly.closeout -- --mode dry-run

# Inspect residual held sets
cat receipts/nightly-closeout/<LATEST_RUN_ID>/local_branch_held.txt
cat receipts/nightly-closeout/<LATEST_RUN_ID>/worktree_held.txt
cat receipts/nightly-closeout/<LATEST_RUN_ID>/remote_origin_held.txt
cat receipts/nightly-closeout/<LATEST_RUN_ID>/remote_github_held.txt

# Apply only after held sets are reduced to safe threshold
OPS_WORKTREE_IDENTITY=WAVE-COORDINATOR-MAINLINE-ENFORCEMENT-AND-CLOSEOUT-AUTONOMY-20260305 \
SPINE_ROLE_POLICY_OVERRIDE_REF=WAVE-COORDINATOR-MAINLINE-ENFORCEMENT-AND-CLOSEOUT-AUTONOMY-20260305 \
SPINE_ROLE_POLICY_OVERRIDE_REASON='post-triage apply check' \
./bin/ops cap run nightly.closeout -- --mode apply
```

