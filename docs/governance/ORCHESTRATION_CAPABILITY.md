---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: orchestration-capability
---

# Orchestration Capability

## Purpose

`orchestration.*` turns loop handoff/integration from prompt conventions into machine checks.

Primary commands:
- `orchestration.loop.open`
- `orchestration.ticket.issue`
- `orchestration.handoff.validate`
- `orchestration.integrate`
- `orchestration.loop.close`
- `orchestration.status`
- `orchestration.terminal.entry`

Runtime state:
- `mailroom/state/orchestration/<loop-id>/manifest.yaml`

## Terminal Entry (Strict)

`orchestration.terminal.entry` is the launcher contract for orchestrator/worker terminals.

Inputs:
- `--loop-id`
- `--role` (`C` or `worker`)
- `--session-id`
- `--worktree` (caller checkout path)
- `--branch` (caller branch claim)
- `--lane` (required for `worker`)
- `--force` (explicit legacy fallback only)

Enforcement:
- Loads loop manifest and target repo from `manifest.repo`.
- Resolves lane branch from ticket first, then manifest.
- Fails if caller branch claim does not match live caller checkout branch.
- Fails if worker lane branch does not match ticket assignment.
- Uses deterministic per-lane worktree:
  - `<repo>/.worktrees/orchestration/<loop-id>/<lane>`
- Fails hard on branch/worktree mismatch.
- Legacy occupied-branch reuse is only allowed with `--force` and prints warning.

Exports:
- `SPINE_ORCH_LOOP_ID`
- `SPINE_ORCH_ROLE`
- `SPINE_ORCH_LANE`
- `SPINE_ORCH_SESSION_ID`
- `SPINE_ORCH_MANIFEST`
- `SPINE_ORCH_TARGET_BRANCH`
- `SPINE_TARGET_REPO`
- `SPINE_WORKTREE`

## Launcher Policy

`workbench/scripts/root/spine_terminal_entry.sh` must:
- Default to capability mode (no silent fallback).
- Use `orchestration.terminal.entry` for orchestrator/worker launches.
- Launch tools from `SPINE_WORKTREE` returned by capability.
- Allow fallback mode only when explicit env gate is enabled and `--force` is provided.

## Expected Safety Properties

- Parallel workers in the same loop resolve to different lane worktrees.
- Wrong lane/branch attaches are blocked before tool launch.
- Worker terminals do not run from `main` by accident.
- Main integration still flows through `validate -> integrate` and sequence checks.
