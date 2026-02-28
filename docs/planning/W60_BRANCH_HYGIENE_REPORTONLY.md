# W60 Branch Hygiene Report (Report-Only)

Date: 2026-02-28 (UTC)  
Mode: report-only (no prune/delete)

## Snapshot

| repo | current_branch | local_branch_count | merged_to_main_count | unmerged_from_main_count |
|---|---|---:|---:|---:|
| `agentic-spine` | `codex/w60-supervisor-canonical-upgrade-20260227` | 4 | 2 | 1 |
| `workbench` | `codex/w60-supervisor-canonical-upgrade-20260227` | 2 | 1 | 0 |
| `mint-modules` | `codex/w60-supervisor-canonical-upgrade-20260227` | 2 | 1 | 0 |

## Candidate Merged Branches (No Action Taken)

### agentic-spine
- `codex/w55-worktree-lifecycle-governance-20260227`
- `codex/w59-three-loop-cleanup-20260227`

### workbench
- `codex/w60-supervisor-canonical-upgrade-20260227` (currently checked out; not eligible for cleanup in-wave)

### mint-modules
- `codex/w60-supervisor-canonical-upgrade-20260227` (currently checked out; not eligible for cleanup in-wave)

## Policy Gate

- Delete/prune blocked in this wave (no `RELEASE_MAIN_CLEANUP_WINDOW` token provided).
- Next eligible lifecycle step is archive-only documentation + explicit token-gated delete window.

## Evidence Commands

- `git branch -vv`
- `git branch --merged main`
- `git branch --no-merged main`
- `git for-each-ref refs/heads --format='%(refname:short)'`
