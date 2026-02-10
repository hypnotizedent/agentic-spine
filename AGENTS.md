# AGENTS.md - Agentic Spine Runtime Contract

> Auto-loaded by local coding tools (Claude Code, Claude Desktop, Codex, etc.).
> Canonical runtime: `/Users/ronnyworks/code/agentic-spine`
> Governance brief source: `docs/governance/AGENT_GOVERNANCE_BRIEF.md`

## Session Entry

1. Start in `/Users/ronnyworks/code/agentic-spine`.
2. Read `docs/governance/SESSION_PROTOCOL.md`.
3. Run `./bin/ops status` to check all open work (loops, gaps, inbox, anomalies).
4. Run `./bin/ops cap list` to discover available governed capabilities.
5. Execute work via `./bin/ops cap run <capability>`.

## Source-Of-Truth Contract

- Canonical governance/runtime: `/Users/ronnyworks/code/agentic-spine`
- Tooling workspace: `/Users/ronnyworks/code/workbench` (read/write tools only)
- Legacy workspace: `$LEGACY_ROOT` (read-only reference only)
- All governed receipts: `/Users/ronnyworks/code/agentic-spine/receipts/sessions`
- All runtime queues/logs/state: `/Users/ronnyworks/code/agentic-spine/mailroom/*`

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

## Work Discovery Rule

- **Never fix inline.** Found a bug, drift, or missing feature? Register it first, then fix through the registration.
- **Gaps:** Add an entry to `ops/bindings/operational.gaps.yaml` with `parent_loop` if one exists.
- **Loops:** Create a scope file in `mailroom/state/loop-scopes/LOOP-<NAME>-<DATE>.scope.md` for any multi-step or cross-file work.
- **Commits reference the loop/gap.** Prefix: `fix(LOOP-X):` or `gov(GAP-OP-NNN):`.
- **Do not ask "want me to fix this?"** — follow the spine: register, fix, receipt.

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

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap list                        # discover capabilities
./bin/ops status                          # unified work status (loops + gaps + inbox)
./bin/ops loops list --open               # list open loops only
./bin/ops start loop <LOOP_ID>            # start worktree for a loop
./bin/ops cap run spine.verify            # full drift check (50+ gates)
./bin/ops cap run spine.status            # quick status
./bin/ops cap run agent.session.closeout  # session closeout (D61)
```
