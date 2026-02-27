---
status: draft
owner: "@ronny"
last_verified: 2026-02-27
scope: worktree-lifecycle-operations
---

# W55 Worktree Lifecycle Runbook V1

## Objective
Standardize all lane worktrees under a single canonical root and eliminate destructive cleanup ambiguity.

## Canonical Policy
- Worktree root: `~/.wt/<repo>/<lane>`
- Lease file: `.spine-lane-lease.yaml`
- Lease owner fields: `owner`, `loop_or_wave_id`, `heartbeat_at`, `ttl_hours`
- Cleanup lifecycle: `report-only` -> `archive-only` -> `delete`
- Delete token gate: `OPS_WORKTREE_DELETE_TOKEN=RELEASE_MAIN_CLEANUP_WINDOW`

## Required Capabilities
- `./bin/ops cap run worktree.lifecycle.reconcile -- --json`
- `./bin/ops cap run worktree.lease.heartbeat`
- `./bin/ops cap run worktree.lifecycle.rehydrate -- --branch codex/<lane> --lane <lane>`
- `./bin/ops cap run worktree.lifecycle.cleanup -- --mode report-only --json`
- `./bin/ops cap run worktree.lifecycle.cleanup -- --mode archive-only`
- `./bin/ops cap run worktree.lifecycle.cleanup -- --mode delete --token RELEASE_MAIN_CLEANUP_WINDOW`

## Enforced Gates
- `D264` worktree root lock
- `D265` active lease delete lock
- `D266` archive-before-delete lock
- `D267` branch-merged-or-explicit-token lock

## Operator Flow
1. Start lane with `ops wave start` (auto-provisions under `~/.wt/<repo>/<WAVE_ID>`).
2. Run `worktree.lease.heartbeat` at session start and before closeout.
3. Close lifecycle owners (`ops wave close` / `ops loops close`) before cleanup.
4. Run cleanup in three phases; do not skip `report-only` and `archive-only`.
5. Use `worktree.lifecycle.rehydrate` if a terminal path disappears but branch still exists.

## Safety Rules
- Never run delete without token.
- Never delete when lease is active.
- Never delete unmerged branches without explicit token.
- Keep protected runtime lanes untouched (mail-archiver / GAP-OP-973 / EWS / MD1400).

## Evidence Outputs
- `receipts/worktree-lifecycle-cleanup/<run_id>/report.json`
- `receipts/worktree-lifecycle-cleanup/<run_id>/report.md`
- `receipts/worktree-lifecycle-cleanup/<run_id>/archive-manifest.json`
- `receipts/worktree-lifecycle-cleanup/<run_id>/actions.log`
