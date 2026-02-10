# Claude Code / Claude Desktop Instructions

> This file is the **project-level** instruction surface for the agentic-spine repo.
> It is loaded automatically by Claude Code and Claude Desktop when opening this project.
> For the full agent contract, see `AGENTS.md` (repo root).

## Session Entry

1. Read `AGENTS.md` for the full runtime contract (commit rules, capability gotchas, drift gates).
2. Run `./bin/ops loops list --open` to check open work.
3. Run `./bin/ops cap list` to discover capabilities.
4. Load full context via `/ctx` or `docs/brain/generate-context.sh`.

## Critical: Main Branch Is Locked

- **Direct commits to `main` are rejected** by a pre-commit hook (except ledger-only changes).
- **Mutating capabilities are blocked on `main`** by the ops runtime.
- You MUST use worktree flow: `./bin/ops start loop <LOOP_ID>` to create a branch, work there, then merge back.
- If you hit "STOP: direct commits to 'main' are blocked", this is expected — switch to a worktree.

## Key Constraints (drift gates enforce these)

- **D30:** No `ronny-ops` references. `~/code/` is the only source tree.
- **D42:** No uppercase `Code` in paths — lowercase `code` only.
- **D48:** Max 2 active worktrees. Clean up after merging.
- **D54/D59:** SSOT bindings must match live infrastructure.
- **D61:** Session closeout required every 48h: `./bin/ops cap run agent.session.closeout`.
- Run `./bin/ops cap run spine.verify` before committing — 50+ gates check everything.

## Identity

- User: Ronny
- GitHub: hypnotizedent

## Quick Reference

- Runtime Repo: `~/code/agentic-spine`
- Workbench Repo: `~/code/workbench`
- Query first: SSOT docs + repo search (`rg`). `mint ask` is deprecated.
- Docker context: check with `docker context show`
