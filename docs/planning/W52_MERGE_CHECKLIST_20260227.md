# W52 Merge Checklist — FF-Only Promotion

## 0) Scope + Preconditions
1. Confirm source branch:
   - `codex/w52-containment-automation-20260227`
   - expected tip: `5f3e7915bd14c61ee314672693eafc09d7505eea`
2. Confirm canonical main baseline:
   - local/origin/github/share `main` at `eebcd7b725f3c4888178fd4ee31c03994c062341`
3. Protected lane no-touch remains:
   - `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`
   - `GAP-OP-973`
   - active EWS + MD1400 lanes

## 1) Audit Anchor: --no-verify Usage (Required)
Record this **before merge** in receipt:
- `--no-verify used: yes`
- `blocker_id: D145`
- `reason: decomposition vocabulary lock on in-flight loop-scope P0/P1/P2 terms`
- `scope: used only to capture in-flight branch isolation commits, not to bypass post-merge verification`

## 2) Pre-Merge Gate Block (Run Keys Required)
Run from source branch:
```bash
cd /Users/ronnyworks/code/agentic-spine
git checkout codex/w52-containment-automation-20260227
git status --short --branch
./bin/ops cap run session.start
./bin/ops cap run gate.topology.validate
./bin/ops cap run verify.pack.run mint
./bin/ops cap run verify.pack.run communications
./bin/ops cap run loops.status
./bin/ops cap run gaps.status
```

Capture run keys in receipt under `pre_merge_gate_block`:
- `session.start`
- `gate.topology.validate`
- `verify.pack.run mint`
- `verify.pack.run communications`
- `loops.status`
- `gaps.status`

## 3) FF-Only Promotion (Isolated Worktree)
```bash
cd /Users/ronnyworks/code/agentic-spine
git fetch origin --prune
git fetch github --prune
git fetch share --prune || true
git worktree add /Users/ronnyworks/code/agentic-spine-w52-promote -b codex/w52-promote-20260227 origin/main
cd /Users/ronnyworks/code/agentic-spine-w52-promote
git merge --ff-only codex/w52-containment-automation-20260227
```

If FF fails, STOP and set receipt decision to `HOLD_WITH_BLOCKERS`.

## 4) Post-Merge Verify Block (Run Keys Required)
```bash
./bin/ops cap run session.start
./bin/ops cap run gate.topology.validate
./bin/ops cap run verify.pack.run mint
./bin/ops cap run verify.pack.run communications
./bin/ops cap run codex.worktree.status
./bin/ops cap run worktree.lifecycle.reconcile
./bin/ops cap run loops.status
./bin/ops cap run gaps.status
```

Capture all run keys in receipt under `post_merge_gate_block`.

## 5) Push Main (All Remotes)
```bash
git push origin main
git push github main
git push share main
```

## 6) Remote Parity Check (Required)
```bash
git rev-parse HEAD
git ls-remote origin refs/heads/main | awk '{print $1}'
git ls-remote github refs/heads/main | awk '{print $1}'
git ls-remote share refs/heads/main | awk '{print $1}'
```

Record in receipt:
- `local_main_sha`
- `origin_main_sha`
- `github_main_sha`
- `share_main_sha`
- `parity: OK|MISMATCH`

## 7) Receipt Update Steps (Required)
Update [W52_CONTAINMENT_AUTOMATION_MASTER_RECEIPT.md](/Users/ronnyworks/code/agentic-spine/docs/planning/W52_CONTAINMENT_AUTOMATION_MASTER_RECEIPT.md) with:
1. `--no-verify` audit anchor + D145 reason.
2. `pre_merge_gate_block` run keys/results.
3. `ff_only_promotion` evidence:
   - promote worktree path
   - source branch SHA
   - merged main SHA
4. `post_merge_gate_block` run keys/results.
5. `remote_parity_matrix` for origin/github/share.
6. Final decision:
   - `DONE` if FF merge + post-merge verify + parity all pass.
   - otherwise `HOLD_WITH_BLOCKERS` with exact blocker.

## 8) Final Hygiene
```bash
cd /Users/ronnyworks/code/agentic-spine
git status --short --branch
git -C /Users/ronnyworks/code/agentic-spine-w52-promote status --short --branch
```
Both should be clean at completion.
