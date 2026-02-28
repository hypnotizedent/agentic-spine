# W75 Branch Delete Plan (20260228)

Policy: report-only unless token `RELEASE_MAIN_CLEANUP_WINDOW` is provided.

## Guard Checks
- delete only `MERGED_SAFE_DELETE` rows
- block if branch is current checked-out branch
- block if branch is not merged into main
- skip missing remote refs

### agentic-spine :: codex/w74-final-closeout-branch-zero-20260228
- head_sha: `62f068ed87b8ff5510bdac86a13092de1c540539`
```bash
git -C /Users/ronnyworks/code/agentic-spine branch -d codex/w74-final-closeout-branch-zero-20260228
git -C /Users/ronnyworks/code/agentic-spine push github --delete codex/w74-final-closeout-branch-zero-20260228
git -C /Users/ronnyworks/code/agentic-spine push origin --delete codex/w74-final-closeout-branch-zero-20260228
git -C /Users/ronnyworks/code/agentic-spine push share --delete codex/w74-final-closeout-branch-zero-20260228
```

