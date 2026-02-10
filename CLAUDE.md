# Claude Code / Claude Desktop Instructions

> Project-level instruction surface for the agentic-spine repo.
> Loaded automatically by Claude Code and Claude Desktop.
> Governance brief source: `docs/governance/AGENT_GOVERNANCE_BRIEF.md`

## Session Entry

1. Read `AGENTS.md` for the full runtime contract.
2. Run `./bin/ops loops list --open` to check open work.
3. Run `./bin/ops cap list` to discover capabilities.
4. Load full context via `/ctx` or `docs/brain/generate-context.sh`.

## Identity

- User: Ronny
- GitHub: hypnotizedent

<!-- GOVERNANCE_BRIEF -->
# Agent Governance Brief

> Canonical source for all agent governance constraints.
> Consumed by: session-entry-hook.sh (Claude Code), AGENTS.md (Codex), CLAUDE.md (Claude Desktop).
> To update: edit this file, then run `ops/hooks/sync-agent-surfaces.sh` to propagate.

## Commit & Branch Rules

- **Commit directly to main.** No ceremony required. Edit, commit, push.
- **Worktrees are optional.** `./bin/ops start loop <LOOP_ID>` creates an isolated worktree if you want one. Not mandatory.
- **If using worktrees, clean up after merging** (D48). Use `ops close loop <LOOP_ID>` to tear down worktree + branch + stashes. Stale/merged/orphaned worktrees fail `spine.verify`.
- **Gitea is canonical** (origin). GitHub is a mirror. D62 enforces.

## Capability Gotchas

- **`approval: manual`** caps prompt for stdin `yes`. In scripts: `echo "yes" | ./bin/ops cap run <cap>`. No `--` separator for args.
- **Preconditions are enforced.** Some caps require `secrets.binding` + `secrets.auth.status` first. If a cap fails with "precondition failed", run the listed precondition cap first.
- **`touches_api: true`** caps always need secrets preconditions — no exceptions (D63 enforces).

## Path & Reference Constraints

- **D30:** No legacy repo references. `~/code/` is the only source tree.
- **D42:** No uppercase `Code` in paths — must be lowercase `code`.
- **D46:** `~/.claude/CLAUDE.md` is a redirect shim only. Governance lives in `docs/brain/`, not `.brain/` (D47).
- **D31:** No log/output files in home root (`~/*.log`, `~/*.out`). Use project paths.
- **D54/D59:** SSOT bindings must match live infrastructure. Adding VMs/hosts requires updates in multiple SSOTs simultaneously.
- **D58:** SSOTs with stale `last_reviewed` dates (>2 weeks) fail verify.

## Verify & Receipts

- Run `./bin/ops cap run spine.verify` before committing — 50+ drift gates check everything.
- Every capability execution auto-generates a receipt. Ledger is append-only.
- D61 enforces session closeout every 48h: `./bin/ops cap run agent.session.closeout`.

## Quick Commands

- `./bin/ops cap list` — discover capabilities
- `./bin/ops status` — unified work status (loops + gaps + inbox)
- `./bin/ops loops list --open` — list open loops only
- `./bin/ops start loop <LOOP_ID>` — start worktree for a loop
- `./bin/ops cap run spine.verify` — full drift check
- `/ctx` — load full governance context
<!-- /GOVERNANCE_BRIEF -->

## Quick Reference

- Runtime Repo: `~/code/agentic-spine`
- Workbench Repo: `~/code/workbench`
- Query first: SSOT docs + repo search (`rg`). `mint ask` is deprecated.
- Docker context: check with `docker context show`
