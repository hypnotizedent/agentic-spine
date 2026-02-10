# AGENTS.md - Agentic Spine Runtime Contract

> Auto-loaded by local coding tools (Claude Code, Claude Desktop, Codex, etc.).
> Canonical runtime: `/Users/ronnyworks/code/agentic-spine`
> Last verified: 2026-02-10

## Session Entry

1. Start in `/Users/ronnyworks/code/agentic-spine`.
2. Read `docs/governance/SESSION_PROTOCOL.md`.
3. Run `./bin/ops loops list --open` to check open work.
4. Run `./bin/ops cap list` to discover available governed capabilities.
5. Execute work via `./bin/ops cap run <capability>`.

## Source-Of-Truth Contract

- Canonical governance/runtime: `/Users/ronnyworks/code/agentic-spine`
- Tooling workspace: `/Users/ronnyworks/code/workbench` (read/write tools only)
- Legacy workspace: `$LEGACY_ROOT` (read-only reference only)
- All governed receipts: `/Users/ronnyworks/code/agentic-spine/receipts/sessions`
- All runtime queues/logs/state: `/Users/ronnyworks/code/agentic-spine/mailroom/*`

## Commit & Branch Rules

**The `main` branch is commit-locked.** A pre-commit hook rejects all commits on `main` except ledger-only changes (`mailroom/state/ledger.csv`).

**Mutating capabilities are blocked on `main`.** `./bin/ops cap run` refuses any capability with `safety: mutating` on the `main` branch.

**Worktree flow is mandatory for all code changes:**
```bash
./bin/ops start loop <LOOP_ID>    # creates .worktrees/codex-<slug>/ on a branch
# ... work inside the worktree directory ...
# commit there, rebase onto main, fast-forward merge
git worktree remove .worktrees/codex-<slug>/   # clean up after merge
```

**Max 2 active worktrees** (enforced by drift gate D48). Stale, merged, or orphaned worktrees fail `spine.verify`.

**Gitea is the canonical remote** (origin). GitHub is a read-only mirror. D62 enforces.

## Capability Gotchas

- **`approval: manual`** capabilities prompt for stdin `yes`. In automated/piped contexts: `echo "yes" | ./bin/ops cap run <cap>`. There is no `--` separator for extra args.
- **Preconditions are enforced.** Some capabilities require `secrets.binding` + `secrets.auth.status` to run first. If a capability fails with "precondition failed", run the listed prerequisite capability first.
- **`touches_api: true`** capabilities always require secrets preconditions — no exceptions (D63 enforces schema).

## Hard Rules

1. Execute mutations via `./bin/ops cap run <capability>` — never raw shell mutations.
2. **No `ronny-ops` references** — `~/code/` is the only source tree (D30).
3. **No uppercase `Code` in paths** — must be lowercase `code` (D42).
4. **`~/.claude/CLAUDE.md` is a redirect shim only.** Governance lives in `docs/brain/`, not `.brain/` (D46/D47).
5. **No log/output files in home root** (`~/*.log`, `~/*.out`, `~/*.err`) — use project paths (D31).
6. **SSOT bindings must match live infrastructure.** Adding VMs/hosts requires updates in multiple SSOTs simultaneously (D54/D59).
7. **SSOTs with stale `last_reviewed` dates (>2 weeks) fail verify** (D58).
8. Query before guessing: read SSOT docs + use `rg`. `mint ask` is deprecated.
9. Close loops with receipts as proof.

## Verify & Receipts

- **Run `./bin/ops cap run spine.verify` before committing** — 50+ drift gates check everything.
- Every capability execution auto-generates a receipt. The ledger is append-only.
- D61 enforces session closeout every 48h: `./bin/ops cap run agent.session.closeout`.

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap list                        # discover capabilities
./bin/ops loops list --open               # check open work
./bin/ops start loop <LOOP_ID>            # start worktree for a loop
./bin/ops cap run spine.verify            # full drift check (50+ gates)
./bin/ops cap run spine.status            # quick status
./bin/ops cap run agent.session.closeout  # session closeout (D61)
```
