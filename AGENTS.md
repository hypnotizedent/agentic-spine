---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: agent-runtime-contract
---

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

<!-- SPINE_STARTUP_BLOCK -->
## Mandatory Startup Block

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops status
./bin/ops cap list
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.route.recommend
./bin/ops cap run verify.domain.run <domain>
./bin/ops cap run spine.verify   # release/nightly certification only
```
<!-- /SPINE_STARTUP_BLOCK -->

## Source-Of-Truth Contract

- Canonical governance/runtime: `/Users/ronnyworks/code/agentic-spine`
- Tooling workspace: `/Users/ronnyworks/code/workbench` (compose, scripts, MCP configs — editable, not a runtime environment)
- Legacy workspace: `$LEGACY_ROOT` (read-only reference only)
- All governed receipts: `/Users/ronnyworks/code/agentic-spine/receipts/sessions`
- All runtime queues/logs/state: `/Users/ronnyworks/code/agentic-spine/mailroom/*`

<!-- GOVERNANCE_BRIEF -->
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: agent-governance-brief
---

# Agent Governance Brief

> Canonical source for all agent governance constraints.
> Consumed by: session-entry-hook.sh (Claude Code), AGENTS.md (Codex), CLAUDE.md (Claude Desktop).
> To update: edit this file, then run `ops/hooks/sync-agent-surfaces.sh` to propagate.

## Commit & Branch Rules

- **Single-agent sessions:** commit directly to `main` is allowed.
- **Multi-agent sessions:** direct commit is disallowed by default; use proposal flow + apply-owner.
- **Worktrees are optional.** `./bin/ops start loop <LOOP_ID>` creates an isolated worktree if you want one. Not mandatory.
- **If using worktrees, clean up after merging** (D48). Use `ops close loop <LOOP_ID>` to tear down worktree + branch + stashes. Stale/merged/orphaned worktrees fail `spine.verify`.
- **Gitea is canonical** (origin). GitHub is a mirror. D62 enforces.

## Multi-Agent Write Policy (Mailroom-Gated Writes)

- **Default rule:** if multiple terminals/agents may be active, treat the repo as **read-only**.
- **Submit changes as proposals:** `./bin/ops cap run proposals.submit "desc"` writes to `mailroom/outbox/proposals/` (gitignored runtime).
- **Operator applies proposals:** `./bin/ops cap run proposals.apply CP-...` creates the commit boundary and prevents “agent B reverted agent A”.
- If you see a dirty worktree you did not create, **STOP** (don’t run cleanup/verify) and coordinate first.

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

## Query Hierarchy

- **Tier 1: Direct read** — if you already know the exact file, read it directly.
- **Tier 2: Capability-first RAG** — for discovery questions (where is X, how does Y work), start with `./bin/ops cap run rag.anythingllm.ask "<question>"`.
- **Tier 3: MCP (optional acceleration)** — use `spine-rag` MCP only when available.
- **Tier 4: `rg` search** — exact-string fallback when capability/MCP discovery is unavailable.
- **Fallback contract:** capability-first RAG is canonical; MCP is optional. Never guess.

## Verify & Receipts

- Day-to-day preflight: run `./bin/ops cap run stability.control.snapshot` then `./bin/ops cap run verify.core.run`.
- Domain work: run `./bin/ops cap run verify.route.recommend` and then `./bin/ops cap run verify.domain.run <domain>`.
- Certification: run `./bin/ops cap run verify.release.run` or `./bin/ops cap run spine.verify` for release/nightly and final cutover.
- Every capability execution auto-generates a receipt. Ledger is append-only.
- Domain updates are impact-scoped: update the domain runbook and add a receipt note via `./bin/ops cap run docs.impact.note <domain> <receipt_run_key>`.
- D61 enforces session closeout every 48h: `./bin/ops cap run agent.session.closeout`.

## Quick Commands

- `./bin/ops cap list` — discover capabilities
- `./bin/ops status` — unified work status (loops + gaps + inbox)
- `./bin/ops loops list --open` — list open loops only
- `./bin/ops start loop <LOOP_ID>` — start worktree for a loop
- `./bin/ops cap run verify.core.run` — Core-8 day-to-day verify lane
- `./bin/ops cap run verify.domain.run <domain>` — domain-scoped verify lane
- `./bin/ops cap run verify.route.recommend` — suggest domain verify lane from current work
- `./bin/ops cap run verify.release.run` — release/nightly full certification lane
- `./bin/ops cap run verify.pack.list` — list verify packs
- `./bin/ops cap run verify.pack.run <agent_id|domain>` — pack-first verify
- `./bin/ops cap run stability.control.snapshot` — runtime reliability snapshot
- `./bin/ops cap run stability.control.reconcile` — guided recovery command planner
- `./bin/ops cap run spine.verify` — full drift check (release/nightly)
- `/ctx` — load full governance context

## Embed Architecture (D65)

This governance brief is **fully embedded** (not pointer-shimmed) in both AGENTS.md and CLAUDE.md.
This is intentional under D65 (agent-briefing-sync-lock): agents must receive the complete
governance brief at session entry without needing to follow references. To update, edit this
file and run `ops/hooks/sync-agent-surfaces.sh` to propagate. Do not convert AGENTS.md or
CLAUDE.md governance blocks to pointer shims — D65 enforces full embed until a future D65-v2
refactor introduces a different delivery mechanism.
<!-- /GOVERNANCE_BRIEF -->

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap list                        # discover capabilities
./bin/ops status                          # unified work status (loops + gaps + inbox)
./bin/ops loops list --open               # list open loops only
./bin/ops start loop <LOOP_ID>            # start worktree for a loop
./bin/ops cap run stability.control.snapshot       # predictive runtime guardrail
./bin/ops cap run verify.core.run                 # Core-8 day-to-day verify lane
./bin/ops cap run verify.route.recommend          # recommend target domain lanes
./bin/ops cap run verify.domain.run <domain>      # domain-scoped verify lane
./bin/ops cap run verify.release.run              # release/nightly full cert lane
./bin/ops cap run spine.verify            # full drift check (release/nightly)
./bin/ops cap run spine.status            # quick status
./bin/ops cap run agent.session.closeout  # session closeout (D61)
```
