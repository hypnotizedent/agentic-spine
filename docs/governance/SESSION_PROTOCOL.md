---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: session-entry
---

# Session Protocol (Spine-native)

> **Purpose:** Entry point for every agent working inside `/Users/ronnyworks/code/agentic-spine`.
> **Why:** Legacy workbench-era session docs are archived and no longer
> represent the spine runtime entry path.

## Before you run anything

1. Confirm you are in the spine repo (`cd /Users/ronnyworks/code/agentic-spine`).
2. Read this document start to finish so you understand how sessions are assembled.
3. Open `docs/brain/README.md` to see the hotkeys, memory rules, and context injection process.
4. Browse `docs/governance/GOVERNANCE_INDEX.md` to learn how governance knowledge is structured and where single sources of truth live.
5. If you operate agents, refer to `docs/governance/AGENTS_GOVERNANCE.md` and `docs/governance/CORE_AGENTIC_SCOPE.md` to understand the lifecycle and trusted directories.

## Session steps

1. **Greet the spine**
   - Run `./bin/ops preflight` or `./bin/ops lane <name>` to print governance hints.
   - Install governance hooks once per clone: `./bin/ops hooks install` (warns in preflight if missing).
   - If you are about to touch secrets, make sure you sourced `~/.config/infisical/credentials` and can run the secrets gating capabilities (`secrets.binding`, `secrets.auth.status`, etc.).
2. **Load context**
   - Generate or read the latest `docs/brain/context.md` if the script is available (see `docs/brain/README.md`).
   - Run `./bin/ops status` to see all open work (loops, gaps, inbox, anomalies). Prioritize closing existing work before starting new work.
   - Check available capabilities: `./bin/ops cap list` (SSOT: `ops/capabilities.yaml`). Do not invent commands.
   - Check available CLI tools: review `ops/bindings/cli.tools.inventory.yaml` or the "Available CLI Tools" section in `context.md`. If a user asks you to use a tool, check this inventory before searching the filesystem or web.
3. **Trace truth**
   - Use SSOT docs + repo search (`rg`) before guessing answers or inventing storylines (Rule 2 from the brain layer). `mint ask` is deprecated.
   - When you need policy or structure, follow the entry chain in `docs/governance/GOVERNANCE_INDEX.md`; trust the highest-priority SSOT in `docs/governance/SSOT_REGISTRY.yaml`.
   - Before guessing remote paths, consult `ops/bindings/docker.compose.targets.yaml` and `ops/bindings/ssh.targets.yaml` first. Never assume stack paths -- bindings are the SSOT for remote host paths.
   - **Before any shop network change:** run `./bin/ops cap run network.shop.audit.status` and do not proceed if it fails (D54 enforces SSOT/binding parity).
4. **Operate through the spine**
   - Every command that mutates must be run through `./bin/ops cap run <capability>` or `./bin/ops run ...` so receipts land in `receipts/sessions/`.
   - **Spine is the runtime environment.** All governed operations (capabilities, receipts, loops) execute here. Editing workbench files (compose configs, MCP configs, scripts) is allowed when a spine loop requires it, but never execute runtime operations from workbench.
   - **Worktrees are optional.** `./bin/ops start loop <LOOP_ID>` creates an isolated worktree if you want one. Committing directly to main is fine.
   - **Git authority:** Gitea (`origin`) is canonical; GitHub is mirror-only. See `docs/governance/GIT_REMOTE_AUTHORITY.md`.
   - **Share publish flow:** To publish curated content to the share channel, run the three-step capability flow: `share.publish.preflight` → `share.publish.preview` → `share.publish.apply --execute`. See `docs/governance/WORKBENCH_SHARE_PROTOCOL.md`.

## Execution Mode Decision Tree

| Scenario | Execution Mode |
|----------|---------------|
| Single read-only query | `ops cap run` (auto-approval) |
| Single mutating action | `ops cap run` (manual approval) |
| Multi-step coordinated work | Open a loop, use proposal flow |
| Quick verify/status check | `ops cap run spine.verify` or `ops status` |

---

## Loop Scope Lifecycle

Valid loop scope status values (all lowercase):

| Status | Meaning |
|--------|---------|
| `planned` | Loop scope defined but work has not started |
| `active` | Work is in progress under this loop |
| `closed` | All work complete, receipts generated, loop finalized |

All loop scope files in `mailroom/state/loop-scopes/` MUST use one of these three values in their status field.

---

## After the session

- Store any learnings in `docs/brain/memory.md` if that system is enabled.
- Close open loops with `./bin/ops loops collect` before wrapping up.
- Always produce receipts for the commands you executed. Receipts live under `receipts/sessions/R*/receipt.md` and prove what you did.

## What Keeps This Predictable (Gates + Governance)

- **Entry governance:** `AGENTS.md` + this `SESSION_PROTOCOL.md` define the canonical workflow: start in the spine repo, list open loops, do work via `./bin/ops cap run ...` / `./bin/ops run ...`, and close loops with receipts.
- **Loop engine:** `./bin/ops loops ...` + `mailroom/state/loop-scopes/*.scope.md` are the shared coordination surface other agents can see.
- **Receipts + ledger:** `receipts/sessions/**/receipt.md` and `mailroom/state/ledger.csv` are the auditable proof trail.
- **Drift gates (enforced by `spine.verify`):**
  - D42 code-path case lock (keeps `~/code/...` canonical, blocks drift like `~/Code/...`).
  - D48 codex worktree hygiene (prevents orphaned/stale codex worktrees/branches).
  - D34 loop ledger integrity (catches loop state inconsistencies).
  - D10/D31 logs/output sink locks (keeps output under mailroom, prevents home-root sinks).
  - D61 session-loop traceability freshness (forces periodic closeout discipline via `agent.session.closeout`).
  - D62 git remote parity (prevents origin/github “split brain” histories).

## Anti-Stash Policy (Gap Lifecycle)

Every open gap in `operational.gaps.yaml` must be linked to an active loop (`parent_loop`).

- **No standalone gaps older than 7 days.** If a gap cannot be loop-linked within 7 days, it must be either: (a) linked to a new or existing loop, or (b) explicitly marked `status: accepted` with owner and acceptance date.
- **"Accepted" gaps** are policy exceptions — the owner acknowledges the gap exists and deliberately defers remediation. They still require periodic review (D58 freshness).
- **`gaps.status` flags orphans and standalone gaps.** Zero orphans and zero unlinked standalone gaps is the target state.
- **Report-and-execute, not report-and-park.** Discovering a gap means registering it AND creating the loop to fix it. Gaps without execution plans are stashed findings.

## Common Causes Of "Non-Uniform Workflow"

- Work started without any loop anchor. Worktrees are optional (committing directly to main is fine), but every non-trivial change should have a loop scope for traceability. Without one you get "floating WIP": no scope anchor and no session log.
- Multiple terminals mutating git concurrently (branches/worktrees/merges in parallel). This creates stale worktrees, branch confusion, and occasional unexpected commits. The coarse git lock in ops commands helps, but ad-hoc git in multiple terminals can still bypass it. **Default rule:** if multiple terminals/agents may be active, treat the repo as read-only and use mailroom-gated writes (change proposals).
- Remote split brain (origin vs github not aligned). Agents base branches off different tips, so “truth” diverges and merges become messy. D62 is specifically to stop that.
- Loop closeout not consistently done. Without updating the loop scope with receipts and closing it, the next agent can’t tell what’s already proven and repeats work. D61 + `agent.session.closeout` is the mechanism meant to prevent this.
- Two repos, two contracts (`agentic-spine` vs `workbench`). If workbench changes aren’t tied back to a spine loop (or vice versa), you get coordination gaps even when each repo is individually clean.

### Codex Worktree Hygiene

When using codex worktrees (`.worktrees/codex-*`):

1. **Create** — branch from `origin/main` (fetch first): `git worktree add .worktrees/<name> -b codex/<name> origin/main`
2. **Base** — never stack codex branches without an explicit `--base` in the PR; rebase before opening PRs.
3. **Proof** — `git status` must be clean inside the worktree; D48 fails `spine.verify` on dirty worktrees.
4. **Retire** — after merge, remove immediately: `ops close loop <LOOP_ID>` or `git worktree remove .worktrees/<name>`; D48 flags merged/dirty/orphaned worktrees and orphaned stashes.

> **Quick checklist**
>
> - [ ] In spine repo
> - [ ] Secrets gating verified
> - [ ] Session bundle reviewed (`SESSION_PROTOCOL`, `brain/README`, `GOVERNANCE_INDEX`)
> - [ ] Codex worktrees pruned (D48)
> - [ ] Open loops recorded
> - [ ] Receipts generated for work
