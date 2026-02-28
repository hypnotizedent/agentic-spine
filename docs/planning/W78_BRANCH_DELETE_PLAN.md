# W78 Branch Delete Plan

Wave: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228
Token required for execution: RELEASE_MAIN_CLEANUP_WINDOW
Current state: report-only, not executed.

## Eligible Branches (MERGED_SAFE_DELETE)

| repo | branch | local_delete_cmd | remote_delete_cmds |
|---|---|---|---|
| agentic-spine | codex/w74-final-closeout-branch-zero-20260228 | `git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w74-final-closeout-branch-zero-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w74-final-closeout-branch-zero-20260228; git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w74-final-closeout-branch-zero-20260228; git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w74-final-closeout-branch-zero-20260228` |
| agentic-spine | codex/w76-holistic-canonical-closure-20260228 | `git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w76-holistic-canonical-closure-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w76-holistic-canonical-closure-20260228; git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w76-holistic-canonical-closure-20260228; git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w76-holistic-canonical-closure-20260228` |
| workbench | codex/w75-weekly-steady-state-20260228 | `git -C /Users/ronnyworks/code/workbench branch -d codex/w75-weekly-steady-state-20260228` | `git -C /Users/ronnyworks/code/workbench push origin --delete codex/w75-weekly-steady-state-20260228; git -C /Users/ronnyworks/code/workbench push github --delete codex/w75-weekly-steady-state-20260228` |
| workbench | codex/w76-holistic-canonical-closure-20260228 | `git -C /Users/ronnyworks/code/workbench branch -d codex/w76-holistic-canonical-closure-20260228` | `git -C /Users/ronnyworks/code/workbench push origin --delete codex/w76-holistic-canonical-closure-20260228; git -C /Users/ronnyworks/code/workbench push github --delete codex/w76-holistic-canonical-closure-20260228` |
| workbench | codex/w77-weekly-steady-state-enforcement-20260228 | `git -C /Users/ronnyworks/code/workbench branch -d codex/w77-weekly-steady-state-enforcement-20260228` | `git -C /Users/ronnyworks/code/workbench push origin --delete codex/w77-weekly-steady-state-enforcement-20260228; git -C /Users/ronnyworks/code/workbench push github --delete codex/w77-weekly-steady-state-enforcement-20260228` |
| mint-modules | codex/w75-weekly-steady-state-20260228 | `git -C /Users/ronnyworks/code/mint-modules branch -d codex/w75-weekly-steady-state-20260228` | `git -C /Users/ronnyworks/code/mint-modules push origin --delete codex/w75-weekly-steady-state-20260228; git -C /Users/ronnyworks/code/mint-modules push github --delete codex/w75-weekly-steady-state-20260228` |

## Guard Checks Before Deletion

1. Branch tip must be ancestor of `main` (`git merge-base --is-ancestor <branch> main`).
2. Branch must not be current checked-out branch.
3. Branch must not be mapped to active protected/background loop ownership.
4. Execute `git fetch --all --prune` after deletion and re-run classification.
