---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-27
scope: local-operator-daily-standard
---

# Local Operator Cockpit

How to operate from the Mac day-to-day without unnecessary ceremony.

## Start of Day

```bash
cd ~/code/agentic-spine
git status                              # Must be: main, clean
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

If `git status` is not `main` + clean, stop and classify before mutating:

```bash
./bin/ops cap run worktree.lifecycle.reconcile -- --json
git checkout main
git pull --ff-only origin main
```

Keep `main` bounded. Use exact-slice landing for small changes and worktrees when isolation helps.

## Parallel Work Model

- Broad or concurrent work belongs in managed worktrees.
- Separate managed worktrees are the normal parallel model.
- Multiple terminals sharing the same root checkout, git index, or protected hotspot surfaces are blocking contention, not parallel work.

## Running a Wave

Always use a managed worktree for real mutation work:

```bash
./bin/ops cap run session.execution.lane.bootstrap \
  --type fix \
  --branch <branch-name> \
  --parent-loop <LOOP-ID>
```

Worktrees are created under `.runtime/spine/tmp/worktrees/{repo}/{branch-slug}`.

After a wave lands:

```bash
git worktree remove <path>
git branch -d <branch>
```

## Controller Landing On Root Main

Root `main` may be dirty only during an explicit controller-owned `staged_only` landing window for one exact slice:

```bash
./bin/ops cap run git.stage.commit.scoped -- \
  --path <exact-file> \
  --message "type(scope): message" \
  --push
```

`git.stage.commit.scoped` is the exact-slice landing path when you want bounded staging on `main`.

## Snapshot Drift

Automated snapshot files (`backup.posture.snapshot.yaml`, `home.dhcp.audit.yaml`, etc.) are not normal root-main WIP. Either discard them or land them as one exact controller slice:

```bash
# Land one exact refresh slice
./bin/ops cap run git.stage.commit.scoped -- \
  --path ops/bindings/backup.posture.snapshot.yaml \
  --message "sync: weekly baseline refresh"

# Or discard if the refresh is not intended
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
| Broad or concurrent mutation | Use a managed worktree when isolation is actually helpful |
| Multiple terminals touching the same root checkout/index | Stop and separate the work into managed worktrees or one controller landing lane |
| Recovery state dirs in git status | Add `ops/plugins/core/recovery/state/` to `.gitignore` |
| Merged worktrees accumulating | Prune after confirming clean + merged |
| 68K+ session receipts | Prune receipts older than 30 days monthly |
| Editing codex config in ~/.codex | Edit in workbench, it's symlinked |

## Quick Health Check

```bash
cd ~/code/agentic-spine

# Should show: main, clean
git status && git log --oneline -1

# Should show: managed worktrees only, no stale residue
git worktree list

# Should show: sibling repos clean before shared operator work
for repo in mint-modules ronny-products agentic-foundation; do
  echo "=== $repo ===" && cd ~/code/$repo && git status --short && cd ~/code/agentic-spine
done
```
