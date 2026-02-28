# W77 Branch Delete Plan

mode: report-only
token_required: RELEASE_MAIN_CLEANUP_WINDOW

## Safe Delete Candidates (MERGED_SAFE_DELETE)

| repo | branch | delete_local | delete_origin | delete_github | delete_share | guard |
|---|---|---|---|---|---|---|
| agentic-spine | codex/w74-final-closeout-branch-zero-20260228 | `git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w74-final-closeout-branch-zero-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w74-final-closeout-branch-zero-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w74-final-closeout-branch-zero-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w74-final-closeout-branch-zero-20260228` | execute only after merge-ancestor + active-lease checks |
| agentic-spine | codex/w76-holistic-canonical-closure-20260228 | `git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w76-holistic-canonical-closure-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w76-holistic-canonical-closure-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w76-holistic-canonical-closure-20260228` | `git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w76-holistic-canonical-closure-20260228` | execute only after merge-ancestor + active-lease checks |
| workbench | codex/w75-weekly-steady-state-20260228 | `git -C /Users/ronnyworks/code/workbench branch -d codex/w75-weekly-steady-state-20260228` | `git -C /Users/ronnyworks/code/workbench push origin --delete codex/w75-weekly-steady-state-20260228` | `git -C /Users/ronnyworks/code/workbench push github --delete codex/w75-weekly-steady-state-20260228` | `n/a` | execute only after merge-ancestor + active-lease checks |
| workbench | codex/w76-holistic-canonical-closure-20260228 | `git -C /Users/ronnyworks/code/workbench branch -d codex/w76-holistic-canonical-closure-20260228` | `git -C /Users/ronnyworks/code/workbench push origin --delete codex/w76-holistic-canonical-closure-20260228` | `git -C /Users/ronnyworks/code/workbench push github --delete codex/w76-holistic-canonical-closure-20260228` | `n/a` | execute only after merge-ancestor + active-lease checks |
| mint-modules | codex/w75-weekly-steady-state-20260228 | `git -C /Users/ronnyworks/code/mint-modules branch -d codex/w75-weekly-steady-state-20260228` | `git -C /Users/ronnyworks/code/mint-modules push origin --delete codex/w75-weekly-steady-state-20260228` | `git -C /Users/ronnyworks/code/mint-modules push github --delete codex/w75-weekly-steady-state-20260228` | `n/a` | execute only after merge-ancestor + active-lease checks |

## Non-delete Classes

- `KEEP_OPEN`: active wave branches remain open.
- `CHERRY_PICK_REQUIRED`: unmerged commits; do not delete.
- `ARCHIVE_ONLY`: none in this wave.
