---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-05
scope: git-authority
---

# Git Remote Authority (Origin-Only Daily Flow)

## Authority Statement

- **Canonical primary:** `origin` (Gitea) is the source of truth and only required remote for daily work.
  - Current origin remote: `ssh://git@100.90.167.39:2222/ronny/agentic-spine.git`
- **Optional mirror:** `github` is release-only. It is not part of day-to-day workflow and must never block canonical progress.

## PR Rule (Canonical)

- Open PRs and merge on **Gitea**.
- Do not open PRs or merge on GitHub for canonical repos. GitHub merges can bypass Gitea CI and create confusing split-brain workflows.

## Branch Push Rule

- Push all branches to **origin** only.
- Do not require `github` or `share` remotes in normal sessions.
- If GitHub publishing is needed, run an explicit release-time push from canonical `origin/main`.

## Release-Time Mirror Recovery (Optional)

1. For a planned release mirror push, run:

```bash
./bin/ops preflight
./bin/ops cap run spine.verify
```

2. If mirror parity checks warn (`origin/main != github/main`):
   - Fetch both:

```bash
git fetch --prune origin main
git fetch --prune github main
```

   - Compare SHAs:

```bash
git rev-parse origin/main
git rev-parse github/main
```

   - Prefer fast-forward reconciliation from canonical:
     - If `origin/main` is ahead, update GitHub mirror by pushing the canonical tip (or repair mirror if automation is broken).
     - If GitHub is ahead due to an accidental GitHub merge, pull the GitHub tip, review, then push to origin to restore canonical history.

3. Re-run verification after mirror repair:

```bash
./bin/ops cap run spine.verify
```

## Share Channel Rule

- A **share** remote may exist for curated release publishing.
- The share channel is NOT canonical and should be absent from normal development sessions.
- Use share only during explicit publishing windows.

## Issue Policy

- **Loops are canonical work tracking** (mailroom loops + receipts).
- Issues are optional. If you create issues, prefer **Gitea issues**.
- Do not duplicate the same issue on both GitHub and Gitea.
