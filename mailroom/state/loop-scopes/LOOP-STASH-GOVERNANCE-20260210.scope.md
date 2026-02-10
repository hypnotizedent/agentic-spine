---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-STASH-GOVERNANCE-20260210
---

# Loop Scope: LOOP-STASH-GOVERNANCE-20260210

## Goal
Add governance for git stashes so orphaned stashes are detected and loop
teardown cleans up worktrees, branches, and stashes in one command.

## Success Criteria
- D48 gate detects orphaned stashes (branch merged or gone) — **DONE**
- `ops close loop <LOOP_ID>` tears down worktree + branch + stashes — **DONE**
- GAP-OP-086 closed — **DONE**

## Phases
- P0: Register GAP-OP-086 — **DONE**
- P1: Expand D48 stash audit — **DONE**
- P2: Add `ops close loop` support to close.sh — **DONE**

## Receipts
- GAP-OP-086 registered in `ops/bindings/operational.gaps.yaml`
- D48 expanded: `surfaces/verify/d48-codex-worktree-hygiene.sh`
- close.sh extended: `ops/commands/close.sh`

## Deferred / Follow-ups
- agent.session.closeout could additionally call `ops close loop` automatically (low priority, agents can call it directly)
