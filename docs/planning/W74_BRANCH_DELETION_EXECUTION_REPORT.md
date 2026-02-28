# W74 Branch Deletion Execution Report

deletion_mode: token-gated execution
token_provided: true
token: RELEASE_MAIN_CLEANUP_WINDOW
executed: yes
source_plan: docs/planning/W74_BRANCH_DELETE_PLAN.md

## Execution Summary
- processed_rows: 25
- local_deleted: 23
- remote_deleted: 34
- skip_missing_or_already_deleted: 32
- blocked_local_delete:
  - agentic-spine/codex/w60-supervisor-canonical-upgrade-20260227 (safe `branch -d` refusal; merged to main but not to historical upstream tracking ref)

See final consolidated receipt: `docs/planning/W74_BRANCH_ZERO_DONE_RECEIPT.md`.
