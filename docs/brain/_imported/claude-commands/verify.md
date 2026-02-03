---
description: Verify work before closing - check ISSUE_CLOSURE_SOP requirements
allowed-tools: Read, Bash(gh:*), Bash(git:*)
---

Before closing issue #$ARGUMENTS, verify per ISSUE_CLOSURE_SOP.md:

1. Read `docs/governance/ISSUE_CLOSURE_SOP.md` for the checklist
2. Run `git status` to confirm changes are committed
3. Run `git log --oneline -5` to confirm commit references the issue
4. Check if the fix requires:
   - Screenshot/output verification from user
   - Deployment confirmation
   - Test passing

DO NOT close the issue yourself. Present the verification checklist and ask the user to confirm each item works.

The rule: "Should work" is NOT verification. User must confirm.
