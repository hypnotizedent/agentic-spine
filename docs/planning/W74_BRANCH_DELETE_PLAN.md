# W74 Branch Delete Plan

Policy: report-only unless token `RELEASE_MAIN_CLEANUP_WINDOW` is explicitly provided.

## Guard Checks

- block delete if branch is not merged into main
- block delete if active lease/loop ownership exists
- block delete if unique commits are not recovered

## Proposed Commands (MERGED_SAFE_DELETE only)

### agentic-spine :: codex/w55-worktree-lifecycle-governance-20260227
- head_sha: `5c86eaf68c393fa06b18679a573d6cd28a14cf41`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w55-worktree-lifecycle-governance-20260227
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w55-worktree-lifecycle-governance-20260227
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w55-worktree-lifecycle-governance-20260227
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w55-worktree-lifecycle-governance-20260227
```

### agentic-spine :: codex/w59-three-loop-cleanup-20260227
- head_sha: `578a50383a8faeb76c0d810541f3e73c31cd8107`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w59-three-loop-cleanup-20260227
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w59-three-loop-cleanup-20260227
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w59-three-loop-cleanup-20260227
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w59-three-loop-cleanup-20260227
```

### agentic-spine :: codex/w60-supervisor-canonical-upgrade-20260227
- head_sha: `1637b1f491d85799ee5c4bebd7dae2a085447cc7`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w60-supervisor-canonical-upgrade-20260227
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w60-supervisor-canonical-upgrade-20260227
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w60-supervisor-canonical-upgrade-20260227
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w60-supervisor-canonical-upgrade-20260227
```

### agentic-spine :: codex/w61-entry-projection-verify-unification-20260228
- head_sha: `2c07e4a337eea4eae95889a80cf35118743f843a`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w61-entry-projection-verify-unification-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w61-entry-projection-verify-unification-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w61-entry-projection-verify-unification-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w61-entry-projection-verify-unification-20260228
```

### agentic-spine :: codex/w62a-cross-repo-tail-remediation-20260228
- head_sha: `6843e38298fb4d0c53e90c9f2c8d71395866b0dd`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w62a-cross-repo-tail-remediation-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w62a-cross-repo-tail-remediation-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w62a-cross-repo-tail-remediation-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w62a-cross-repo-tail-remediation-20260228
```

### agentic-spine :: codex/w62b-learning-system-20260228
- head_sha: `6c99a0ba2d04d24f80088b8ed3a215e3a8477d81`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w62b-learning-system-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w62b-learning-system-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w62b-learning-system-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w62b-learning-system-20260228
```

### agentic-spine :: codex/w63-outcome-closure-automation-20260228
- head_sha: `430d95fcc5ec31c1517593630a92f9d9c2bded53`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w63-outcome-closure-automation-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w63-outcome-closure-automation-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w63-outcome-closure-automation-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w63-outcome-closure-automation-20260228
```

### agentic-spine :: codex/w64-backlog-throughput-closure-20260228
- head_sha: `d5c4cb572de47557ea251105fa0cb1423e9fcf0c`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w64-backlog-throughput-closure-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w64-backlog-throughput-closure-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w64-backlog-throughput-closure-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w64-backlog-throughput-closure-20260228
```

### agentic-spine :: codex/w65-control-loop-completion-20260228
- head_sha: `dbc18d53e9f630ff60afbfac690aa05cdb821186`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w65-control-loop-completion-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w65-control-loop-completion-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w65-control-loop-completion-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w65-control-loop-completion-20260228
```

### agentic-spine :: codex/w66-w67-projection-enforcement-20260228
- head_sha: `cf7aba99f34262cbefce1d77ada7b90520e6fd2b`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w66-w67-projection-enforcement-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w66-w67-projection-enforcement-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w66-w67-projection-enforcement-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w66-w67-projection-enforcement-20260228
```

### agentic-spine :: codex/w69-branch-drift-registration-hardening-20260228
- head_sha: `19251b1720952f6a16ead3f5d34da4ea0a1147af`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w69-branch-drift-registration-hardening-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w69-branch-drift-registration-hardening-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w69-branch-drift-registration-hardening-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w69-branch-drift-registration-hardening-20260228
```

### agentic-spine :: codex/w70-workbench-verify-budget-calibration-20260228
- head_sha: `3c0cb3d8d3fa4d383ca719f876f45bb0ada4974e`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w70-workbench-verify-budget-calibration-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w70-workbench-verify-budget-calibration-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w70-workbench-verify-budget-calibration-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w70-workbench-verify-budget-calibration-20260228
```

### agentic-spine :: codex/w71-final-completion-drift-burndown-20260228
- head_sha: `226c0d6049429ead2a12f46d97f021a0c3d8cd11`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w71-final-completion-drift-burndown-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w71-final-completion-drift-burndown-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w71-final-completion-drift-burndown-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w71-final-completion-drift-burndown-20260228
```

### agentic-spine :: codex/w72-runtime-recovery-20260228
- head_sha: `618f2fcd2a96bbc0422c5bba1455d64048daa2e6`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w72-runtime-recovery-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w72-runtime-recovery-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w72-runtime-recovery-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w72-runtime-recovery-20260228
```

### agentic-spine :: codex/w72-w73-promote-20260228
- head_sha: `ed73f0a72227fafcf05c5845fe9cec93e40e8d18`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w72-w73-promote-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w72-w73-promote-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w72-w73-promote-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w72-w73-promote-20260228
```

### workbench :: codex/w60-supervisor-canonical-upgrade-20260227
- head_sha: `e1d97b7318b3415e8cafef30c7c494a585e7aec6`
```bash
git -C /Users/ronnyworks/code/workbench branch -d codex/w60-supervisor-canonical-upgrade-20260227
git -C /Users/ronnyworks/code/workbench push origin --delete codex/w60-supervisor-canonical-upgrade-20260227
git -C /Users/ronnyworks/code/workbench push github --delete codex/w60-supervisor-canonical-upgrade-20260227
```

### workbench :: codex/w61-entry-projection-verify-unification-20260228
- head_sha: `e1d97b7318b3415e8cafef30c7c494a585e7aec6`
```bash
git -C /Users/ronnyworks/code/workbench branch -d codex/w61-entry-projection-verify-unification-20260228
git -C /Users/ronnyworks/code/workbench push origin --delete codex/w61-entry-projection-verify-unification-20260228
git -C /Users/ronnyworks/code/workbench push github --delete codex/w61-entry-projection-verify-unification-20260228
```

### workbench :: codex/w69-branch-drift-registration-hardening-20260228
- head_sha: `5a67eb5daca70b2f34a3a5ebd29151ef9541d1a6`
```bash
git -C /Users/ronnyworks/code/workbench branch -d codex/w69-branch-drift-registration-hardening-20260228
git -C /Users/ronnyworks/code/workbench push origin --delete codex/w69-branch-drift-registration-hardening-20260228
git -C /Users/ronnyworks/code/workbench push github --delete codex/w69-branch-drift-registration-hardening-20260228
```

### workbench :: codex/w71-final-completion-drift-burndown-20260228
- head_sha: `5a67eb5daca70b2f34a3a5ebd29151ef9541d1a6`
```bash
git -C /Users/ronnyworks/code/workbench branch -d codex/w71-final-completion-drift-burndown-20260228
git -C /Users/ronnyworks/code/workbench push origin --delete codex/w71-final-completion-drift-burndown-20260228
git -C /Users/ronnyworks/code/workbench push github --delete codex/w71-final-completion-drift-burndown-20260228
```

### workbench :: codex/w74-final-closeout-branch-zero-20260228
- head_sha: `5a67eb5daca70b2f34a3a5ebd29151ef9541d1a6`
```bash
git -C /Users/ronnyworks/code/workbench branch -d codex/w74-final-closeout-branch-zero-20260228
git -C /Users/ronnyworks/code/workbench push origin --delete codex/w74-final-closeout-branch-zero-20260228
git -C /Users/ronnyworks/code/workbench push github --delete codex/w74-final-closeout-branch-zero-20260228
```

### mint-modules :: codex/w60-supervisor-canonical-upgrade-20260227
- head_sha: `b98bf32126ad931842a2bb8983c3b8194286a4fd`
```bash
git -C /Users/ronnyworks/code/mint-modules branch -d codex/w60-supervisor-canonical-upgrade-20260227
git -C /Users/ronnyworks/code/mint-modules push origin --delete codex/w60-supervisor-canonical-upgrade-20260227
git -C /Users/ronnyworks/code/mint-modules push github --delete codex/w60-supervisor-canonical-upgrade-20260227
```

### mint-modules :: codex/w61-entry-projection-verify-unification-20260228
- head_sha: `b98bf32126ad931842a2bb8983c3b8194286a4fd`
```bash
git -C /Users/ronnyworks/code/mint-modules branch -d codex/w61-entry-projection-verify-unification-20260228
git -C /Users/ronnyworks/code/mint-modules push origin --delete codex/w61-entry-projection-verify-unification-20260228
git -C /Users/ronnyworks/code/mint-modules push github --delete codex/w61-entry-projection-verify-unification-20260228
```

### mint-modules :: codex/w69-branch-drift-registration-hardening-20260228
- head_sha: `fb2105c3309c8d802b9930349c811e2fc4954354`
```bash
git -C /Users/ronnyworks/code/mint-modules branch -d codex/w69-branch-drift-registration-hardening-20260228
git -C /Users/ronnyworks/code/mint-modules push origin --delete codex/w69-branch-drift-registration-hardening-20260228
git -C /Users/ronnyworks/code/mint-modules push github --delete codex/w69-branch-drift-registration-hardening-20260228
```

### mint-modules :: codex/w71-final-completion-drift-burndown-20260228
- head_sha: `fb2105c3309c8d802b9930349c811e2fc4954354`
```bash
git -C /Users/ronnyworks/code/mint-modules branch -d codex/w71-final-completion-drift-burndown-20260228
git -C /Users/ronnyworks/code/mint-modules push origin --delete codex/w71-final-completion-drift-burndown-20260228
git -C /Users/ronnyworks/code/mint-modules push github --delete codex/w71-final-completion-drift-burndown-20260228
```

### mint-modules :: codex/w74-final-closeout-branch-zero-20260228
- head_sha: `fb2105c3309c8d802b9930349c811e2fc4954354`
```bash
git -C /Users/ronnyworks/code/mint-modules branch -d codex/w74-final-closeout-branch-zero-20260228
git -C /Users/ronnyworks/code/mint-modules push origin --delete codex/w74-final-closeout-branch-zero-20260228
git -C /Users/ronnyworks/code/mint-modules push github --delete codex/w74-final-closeout-branch-zero-20260228
```

