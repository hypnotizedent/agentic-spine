# W60 Branch Hygiene Report (Report-Only)

Date: 2026-02-28 (UTC)
Mode: report-only
Delete/prune token: not provided (`RELEASE_MAIN_CLEANUP_WINDOW` absent)

| repo | current_branch | local_branches | merged_to_main | no_merged_to_main | dirty_entries |
|---|---|---:|---:|---:|---:|
| `agentic-spine` | `codex/w60-supervisor-canonical-upgrade-20260227` | 4 | 3 | 1 | 58 |
| `workbench` | `codex/w60-supervisor-canonical-upgrade-20260227` | 2 | 1 | 1 | 40 |
| `mint-modules` | `codex/w60-supervisor-canonical-upgrade-20260227` | 2 | 1 | 1 | 10 |

## Observations

- Branch cleanup remains report-only in W60.
- No branch prune/delete executed.
- Current wave branch remains active in all three repos.

## Evidence

- `git branch --show-current`
- `git branch --list | wc -l`
- `git branch --merged main | wc -l`
- `git branch --no-merged main | wc -l`
- `git status --short | wc -l`
