---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-05
scope: git-worktree-hygiene
---

# Git / Worktree Hygiene

Temporary operational branches live under the `codex/` namespace.
Machine policy:

`ops/bindings/git.worktree.hygiene.policy.yaml`

Policy:
- `codex/preserve-*` is `preserve` and is never auto-pruned by hygiene automation
- other `codex/*` branches are treated as ephemeral operational branches
- pruning is allowed only when the branch or worktree is boring:
  - already landed on `origin/main`
  - carries zero unique commits relative to `origin/main`
  - has no non-prunable worktree attachment

Run inventory only:

```bash
python3 ./ops/plugins/core/lifecycle/bin/git-worktree-hygiene --brief
```

Apply safe prune actions:

```bash
python3 ./ops/plugins/core/lifecycle/bin/git-worktree-hygiene --apply --brief
```

Run explicit git maintenance after prune:

```bash
python3 ./ops/plugins/core/lifecycle/bin/git-worktree-hygiene --apply --maintenance --brief
```

Dry-run is the default. There is no silent pruning.
