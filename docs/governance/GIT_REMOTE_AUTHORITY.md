---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-24
scope: git-authority
---

# Git Remote Authority (Gitea Canonical, GitHub Mirror)

## Authority Statement

- **Canonical primary:** `origin` (Gitea) is the source of truth.
  - Current origin remote: `ssh://git@100.90.167.39:2222/ronny/agentic-spine.git`
- **Mirror only:** `github` (GitHub) is a push mirror for parity, backup, and visibility.

## PR Rule (Canonical)

- Open PRs and merge on **Gitea**.
- Do not open PRs or merge on GitHub for canonical repos. GitHub merges can bypass Gitea CI and create confusing split-brain workflows.

## Branch Push Rule

- Push feature branches to **origin** only.
- Let the Gitea mirror populate GitHub.
- GitHub is mirror-only and must not be required for canonical work.
- If the GitHub mirror is down or diverged, fix it later; do not block the spine.

## Split-Brain Recovery (Origin vs GitHub)

1. Run:

```bash
./bin/ops preflight
./bin/ops cap run spine.verify
```

2. If D62 fails (origin/main != github/main):
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

3. Re-run:

```bash
./bin/ops cap run spine.verify
```

## Share Channel Rule

- A **share** remote may exist for curated one-way publishing to a private GitHub repository.
- The share channel is NOT canonical — Gitea (`origin`) remains the single source of truth.
- Share publishes are governed by `docs/governance/WORKBENCH_SHARE_PROTOCOL.md` and enforced by D82.
- The share remote is manual-push only (no automation, dry-run default).
- Do not pull from or merge into the share remote.

## Issue Policy

- **Loops are canonical work tracking** (mailroom loops + receipts).
- Issues are optional. If you create issues, prefer **Gitea issues**.
- Do not duplicate the same issue on both GitHub and Gitea.
