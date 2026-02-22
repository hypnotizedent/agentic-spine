---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: agent-runtime-contract
---

# AGENTS.md - Agentic Spine Runtime Contract

> Auto-loaded by local coding tools (Claude Code, Claude Desktop, Codex, etc.).
> Canonical runtime: `~/code/agentic-spine`
> Governance brief source: `docs/governance/AGENT_GOVERNANCE_BRIEF.md`

## Session Entry

1. Start in `~/code/agentic-spine`.
2. Read `docs/governance/SESSION_PROTOCOL.md`.
3. Run `./bin/ops cap run session.start` for fast startup status and verify routing.
4. Run `./bin/ops cap list` only when you need to discover a specific capability.
5. Execute work via `./bin/ops cap run <capability>`.

<!-- SPINE_STARTUP_BLOCK -->
## Mandatory Startup Block

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.start

# Legacy full startup lane (kept for parity and manual opt-in):
# ./bin/ops status
# ./bin/ops cap run stability.control.snapshot
# ./bin/ops cap run verify.core.run
```
<!-- /SPINE_STARTUP_BLOCK -->

## Post-Work Verify (run after domain changes, before commit)

```bash
./bin/ops cap run verify.route.recommend          # tells you which domain pack to run
./bin/ops cap run verify.pack.run <domain>         # runs domain-specific gates
```

## Release Certification (nightly / release only)

```bash
./bin/ops cap run verify.release.run              # full 148-gate suite (requires Tailscale)
```

## Source-Of-Truth Contract

- Canonical governance/runtime: `~/code/agentic-spine`
- Tooling workspace: `~/code/workbench` (compose, scripts, MCP configs — editable, not a runtime environment)
- Legacy workspace: `$LEGACY_ROOT` (read-only reference only)
- All governed receipts: `~/code/agentic-spine/receipts/sessions`
- Mailroom runtime root contract: `~/code/agentic-spine/ops/bindings/mailroom.runtime.contract.yaml`
- Active runtime queues/logs/state: `~/code/.runtime/spine-mailroom/*` when contract `active: true`

<!-- GOVERNANCE_BRIEF -->
---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: agent-governance-brief
---

# Agent Governance Brief

> Canonical source for all agent governance constraints.
> Consumed by: session-entry surfaces via `spine.context`.
> `ops/hooks/sync-agent-surfaces.sh` is retired; update this file as the source of truth.

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
- **Proposal action contract:** proposal changes must use `create|modify|delete` (with known aliases). `append` is invalid and rejected at apply time.

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

- **Session start:** `stability.control.snapshot` then `verify.core.run` (8 gates, <60s, no network).
- **After domain work:** `verify.route.recommend` → `verify.pack.run <domain>` (domain-specific gates only).
- **Release/nightly:** `verify.release.run` (full 148-gate suite, requires Tailscale).
- **Network gates** have Tailscale guards — they SKIP cleanly when VPN is disconnected, never hang or popup.
- Every capability execution auto-generates a receipt. Ledger is append-only.
- D61 enforces session closeout every 48h: `./bin/ops cap run agent.session.closeout`.

## Quick Commands

- `./bin/ops status` — unified work status (loops + gaps + inbox)
- `./bin/ops cap list` — discover capabilities
- `./bin/ops cap run stability.control.snapshot` — runtime reliability snapshot
- `./bin/ops cap run verify.core.run` — Core-8 preflight (<60s, no network)
- `./bin/ops cap run verify.route.recommend` — which domain pack to run after work
- `./bin/ops cap run verify.pack.run <domain>` — domain-specific verify
- `./bin/ops cap run verify.release.run` — full 148-gate certification (requires Tailscale)
- `./bin/ops loops list --open` — list open loops only
- `/ctx` — load full governance context

## Delivery Architecture (D65)

Canonical governance delivery is now `spine.context` (brief section). Embedded copies in
`AGENTS.md` and `CLAUDE.md` remain compatibility snapshots and may lag. If any mismatch appears,
this file is authoritative.
<!-- /GOVERNANCE_BRIEF -->

## Canonical Terminal Roles

| ID | Type | Scope |
|----|------|-------|
| SPINE-CONTROL-01 | control-plane | bin/, ops/, surfaces/, docs/governance/, docs/core/, docs/product/, docs/brain/, mailroom/ |
| SPINE-AUDIT-01 | observation | receipts/, docs/governance/_audits/ |
| DOMAIN-HA-01 | domain-runtime | ops/plugins/ha/, ops/agents/home-assistant-agent.contract.md |
| RUNTIME-IMMICH-01 | domain-runtime | ops/plugins/immich/, ops/agents/immich-agent.contract.md |
| DEPLOY-MINT-01 | domain-runtime | ops/plugins/mint/, ops/agents/mint-agent.contract.md |

> Source: `ops/bindings/terminal.role.contract.yaml`

## Canonical Commands

```bash
cd ~/code/agentic-spine

# Session start (mandatory — 3 commands, <60s total)
./bin/ops cap run session.start

# After domain work (before commit)
./bin/ops cap run verify.route.recommend
./bin/ops cap run verify.pack.run <domain>

# Release/nightly only
./bin/ops cap run verify.release.run

# Work management
./bin/ops cap list
./bin/ops loops list --open
./bin/ops start loop <LOOP_ID>
./bin/ops cap run agent.session.closeout
```
