---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
scope: local-operator-daily-standard
---

# Local Operator Cockpit

How to operate from the Mac day-to-day without creating local drift.

## Start of Day

```bash
cd ~/code/agentic-spine
git status                              # Must be: main, clean
./bin/ops cap run session.start         # Orientation
```

If `git status` shows you're not on main or not clean:
```bash
git stash                               # Or: git checkout -- <files>
git checkout main
git pull origin main
```

## Running a Wave

Always use a managed worktree, never the primary checkout:

```bash
# Worktrees are created by the system under:
# .runtime/spine/tmp/worktrees/{repo}/{branch-slug}
```

After a wave merges to main:
```bash
git worktree remove <path>
git branch -d <branch>
```

## Committing to Main

```bash
OPS_GOVERNED_MAIN_OVERRIDE=1 git commit -m "type(scope): message"
OPS_GOVERNED_MAIN_OVERRIDE=1 git push origin main
```

## Snapshot Drift

Automated snapshot files (`backup.posture.snapshot.yaml`, `home.dhcp.audit.yaml`, etc.) change on cap runs. Handle them at session boundaries:

```bash
# Option A: Commit as sync
git add ops/bindings/*.snapshot.yaml
OPS_GOVERNED_MAIN_OVERRIDE=1 git commit -m "sync: weekly baseline refresh"

# Option B: Discard
git checkout -- ops/bindings/*.snapshot.yaml
```

## Where Things Go

| What | Where |
|------|-------|
| Wave work | Managed worktree under `.runtime/spine/tmp/worktrees/` |
| Evidence and reports | `.evidence/spine/verify/` |
| Session receipts | `.evidence/spine/sessions/` (auto, prune >30 days) |
| Loop closeouts | `.evidence/spine/loop-closeouts/` |
| Domain data | `.data/{domain}/` |
| Backups and tombstones | `.backups/` |
| Codex config changes | `workbench/dotfiles/codex/` (symlinked into ~/.codex) |

## Common Traps

| Trap | Fix |
|------|-----|
| Primary checkout on feature branch | Switch to main before daily work |
| Recovery state dirs in git status | Add `ops/plugins/core/recovery/state/` to `.gitignore` |
| Merged worktrees accumulating | Prune after confirming clean + merged |
| 68K+ session receipts | Prune receipts older than 30 days monthly |
| Editing codex config in ~/.codex | Edit in workbench, it's symlinked |

## Quick Health Check

```bash
cd ~/code/agentic-spine

# Should show: main, clean, 0/0 ahead/behind
git status && git log --oneline -1

# Should show: no merged worktrees lingering
git worktree list

# Should show: all repos clean on main
for repo in mint-modules ronny-products agentic-foundation; do
  echo "=== $repo ===" && cd ~/code/$repo && git status --short && cd ~/code/agentic-spine
done
```
