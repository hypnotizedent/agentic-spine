---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: session-entry
---

# Session Protocol (Spine-native)

> **Purpose:** Entry point for every agent working with the agentic-spine,
> regardless of device or surface (desktop CLI, mobile, remote/tailnet).
>
> **Canonical output schemas:** `docs/governance/OUTPUT_CONTRACTS.md`

---

## Step 0: Detect Your Environment

Before doing anything else, determine which surface you are on. Your allowed
actions, session steps, and output paths depend on this.

### Detection Signals

| Signal | Desktop | Mobile | Remote |
|--------|---------|--------|--------|
| Can read `~/code/agentic-spine/` files | Yes | No | No |
| `./bin/ops` CLI available | Yes | No | No |
| MCP tools (spine-rag) available | Yes | No | Maybe |
| Mailroom bridge reachable | localhost:8799 | tailnet only | tailnet only |
| Can commit to git | Yes | No | No |
| Can run drift gates | Yes | No | No |

**Desktop:** You can read files from `~/code/agentic-spine` and run `./bin/ops`.
**Mobile:** You are on claude.ai or a mobile app with no filesystem, no CLI, no MCP.
**Remote:** You have network access (tailnet/bridge) but no local filesystem.
**Unknown:** None of the above signals are confirmed. Enter safe mode (below).

---

## Environment: Desktop

Full spine access. Follow all sections below in order.

### Before you run anything

1. Confirm you are in the spine repo (`cd /Users/ronnyworks/code/agentic-spine`).
2. Read this document start to finish so you understand how sessions are assembled.
3. Open `docs/brain/README.md` to see the hotkeys, memory rules, and context injection process.
4. Browse `docs/governance/GOVERNANCE_INDEX.md` to learn how governance knowledge is structured and where single sources of truth live.
5. If you operate agents, refer to `docs/governance/AGENTS_GOVERNANCE.md` and `docs/governance/CORE_AGENTIC_SCOPE.md` to understand the lifecycle and trusted directories.
6. For cross-repo parallel work, read `docs/governance/RUNWAY_TOOLING_PRODUCT_OPERATING_CONTRACT_V1.md` before opening additional write terminals.

### Session steps

1. **Greet the spine**
   - Run `./bin/ops preflight` or `./bin/ops lane list` to print governance hints.
   - Confirm gate domain pack routing before mutation:
     - `./bin/ops cap run verify.drift_gates.certify --list-domains`
     - `./bin/ops cap run verify.drift_gates.certify --domain <name> --brief`
   - Confirm agent-scoped verify packs:
     - `./bin/ops cap run verify.pack.list`
     - `./bin/ops cap run verify.pack.explain <agent_id|domain>`
   - Set `OPS_GATE_DOMAIN=<name>` (default is `core`) so preflight prints the active domain pack inline.
   - Install governance hooks once per clone: `./bin/ops hooks install` (warns in preflight if missing).
   - If you are about to touch secrets, make sure you sourced `~/.config/infisical/credentials` and can run the secrets gating capabilities (`secrets.binding`, `secrets.auth.status`, etc.).
2. **Load context**
   - Generate or read the latest `docs/brain/context.md` if the script is available (see `docs/brain/README.md`).
   - Run `./bin/ops status` to see all open work (loops, gaps, inbox, anomalies). Prioritize closing existing work before starting new work.
   - Enforce migration-era WIP cap: max 3 active loops. If 3+ loops are active, do not open a new loop until one closes.
   - Use a 3-card intake before mutation work:
     - objective (single sentence)
     - done check (how completion will be verified)
     - first command (deterministic first execution step)
   - Check available capabilities: `./bin/ops cap list` (SSOT: `ops/capabilities.yaml`). Do not invent commands.
   - Check available CLI tools: review `ops/bindings/cli.tools.inventory.yaml` or the "Available CLI Tools" section in `context.md`. If a user asks you to use a tool, check this inventory before searching the filesystem or web.
3. **Trace truth**
   - Use the query hierarchy before guessing answers or inventing storylines (Rule 2 from the brain layer): if the exact file is known, read it directly; otherwise start with capability-first RAG (`./bin/ops cap run rag.anythingllm.ask "<query>"`) → optional `spine-rag` MCP acceleration → `rg` fallback. `mint ask` is deprecated.
   - When you need policy or structure, follow the entry chain in `docs/governance/GOVERNANCE_INDEX.md`; trust the highest-priority SSOT in `docs/governance/SSOT_REGISTRY.yaml`.
   - Before guessing remote paths, consult `ops/bindings/docker.compose.targets.yaml` and `ops/bindings/ssh.targets.yaml` first. Never assume stack paths -- bindings are the SSOT for remote host paths.
   - **Before any shop network change:** run `./bin/ops cap run network.shop.audit.status` and do not proceed if it fails (D54 enforces SSOT/binding parity).
4. **Operate through the spine**
   - Every command that mutates must be run through `./bin/ops cap run <capability>` or `./bin/ops run ...` so receipts land in `receipts/sessions/`.
   - **Spine is the runtime environment.** All governed operations (capabilities, receipts, loops) execute here. Editing workbench files (compose configs, MCP configs, scripts) is allowed when a spine loop requires it, but never execute runtime operations from workbench.
   - **Worktrees are optional.** `./bin/ops start loop <LOOP_ID>` creates an isolated worktree if you want one. Committing directly to main is fine.
   - **Git authority:** Gitea (`origin`) is canonical; GitHub is mirror-only. See `docs/governance/GIT_REMOTE_AUTHORITY.md`.
   - **Share publish flow:** To publish curated content to the share channel, run the three-step capability flow: `share.publish.preflight` → `share.publish.preview` → `share.publish.apply --execute`. See `docs/governance/WORKBENCH_SHARE_PROTOCOL.md`.
   - **Impact-scoped docs:** for domain work, update only the domain runbook and create a receipt note with `./bin/ops cap run docs.impact.note <domain> <receipt_run_key>`.

### Execution Mode Decision Tree

| Scenario | Execution Mode |
|----------|---------------|
| Single read-only query | `ops cap run` (auto-approval) |
| Single mutating action | `ops cap run` (manual approval) |
| Multi-step coordinated work | Open a loop, use proposal flow |
| Quick verify/status check | `ops cap run lane.standard.run` |
| Release/nightly certification | `ops cap run spine.verify` |

### Gate Domain Packs (Terminal Routing)

Use domain packs to make gate applicability explicit before mutation work.

- Canonical binding: `ops/bindings/gate.domain.profiles.yaml`
- Domain list: `core`, `aof`, `secrets`, `infra`, `workbench`, `loop_gap`, `home`, `media`, `immich`, `n8n`, `finance`, `ms-graph`, `rag`
- Terminal default: `OPS_GATE_DOMAIN` unset -> `core`

Recommended pre-mutation command:

```bash
./bin/ops cap run lane.standard.run
```

Daily lane report artifacts:

- `mailroom/outbox/operations/daily-lane/daily-lane-latest.md`
- `mailroom/outbox/operations/daily-lane/daily-lane-latest.json`

### After the session (Desktop)

- Store any learnings in `docs/brain/memory.md` if that system is enabled.
- Close open loops with `./bin/ops loops close <loop_id>` before wrapping up.
- Always produce receipts for the commands you executed. Receipts live under `receipts/sessions/R*/receipt.md` and prove what you did.

---

## Environment: Mobile

No filesystem. No CLI. You are a planning and drafting surface.

### Allowed Actions

- Analyze, plan, and produce structured artifacts using output contracts
- Draft loop scopes, gap filings, and proposal manifests (see Output Contracts below)
- Query mailroom bridge if exposed on tailnet: `GET http://<tailnet-host>/loops/open`
- Produce handoff blocks for a desktop session to execute

### Blocked Actions

- Do NOT attempt file reads, CLI commands, or git operations
- Do NOT produce unstructured notes — use the output contract YAML blocks
- Do NOT guess gap IDs — use `GAP-OP-NNN` and let desktop resolve the actual ID
- Do NOT declare work "fixed" — only desktop can run `gaps.close` and `spine.verify`

### Session Steps (Mobile)

1. **State your environment** — "I am on mobile. No CLI or filesystem access."
2. **Ask for current state** — Request the operator paste `./bin/ops status` output, or query bridge if available.
3. **Work within contracts** — All outputs must use the YAML blocks defined in Output Contracts below.
4. **Produce a handoff** — End the session with a structured handoff block containing all drafted artifacts, ready for desktop ingestion.

### Mobile Handoff Block Format

```markdown
## Mobile Handoff — YYYY-MM-DD

### Drafted Artifacts (for desktop ingestion)

[gap YAML blocks, loop scope blocks, or proposal manifests here]

### Context for Desktop Session

- Current state: [what you learned]
- Recommended next action: [specific command or gap to file]
- Blockers: [anything that needs operator input]
```

---

## Environment: Remote

Network access via tailnet. No local filesystem.

### Allowed Actions

- Query mailroom bridge: `GET/POST http://<tailnet-host>/...`
  - `GET /loops/open` — list open loops
  - `GET /outbox/read` — read proposal queue
  - `POST /inbox/enqueue` — enqueue work items
  - `POST /rag/ask` — query governed RAG over bridge
  - `POST /cap/run` — execute allowlisted read-only capability over bridge
- Query RAG if exposed via MCP or bridge
- Draft artifacts using output contract formats

### Blocked Actions

- Do NOT attempt local file reads or CLI commands
- Do NOT assume bridge is exposed — verify with health check first: `GET /health`

### Fallback

If bridge is unreachable, fall back to Mobile behavior.

---

## Environment: Unknown (Safe Mode)

Cannot confirm filesystem, CLI, bridge, or MCP access.

1. Do NOT attempt any mutations (file writes, git, API calls).
2. Do NOT assume any paths exist.
3. Produce all outputs as portable YAML blocks using output contracts.
4. Mark all drafted artifacts with `discovered_by: "unknown-env-session-YYYYMMDD"`.
5. Ask the operator to confirm environment before executing anything.

---

## Output Contracts

**Canonical source:** `docs/governance/OUTPUT_CONTRACTS.md`

All spine artifacts must conform to these schemas regardless of environment.
Desktop sessions write directly to the repo. Mobile and remote sessions produce
the YAML blocks below for desktop ingestion.

### Loop Scope (frontmatter)

```yaml
---
loop_id: LOOP-DESCRIPTIVE-NAME-YYYYMMDD
created: YYYY-MM-DD
status: planned          # planned | active | closed
owner: "@ronny"
scope: agentic-spine
objective: One-line description of the goal
---
```

Required sections: `## Problem Statement`, `## Deliverables`, `## Acceptance Criteria`, `## Constraints`.

Full schema: `docs/governance/OUTPUT_CONTRACTS.md` section 1.

### Gap Filing

```yaml
gap:
  id: GAP-OP-NNN          # Desktop resolves actual ID
  type: missing-entry      # stale-ssot | missing-entry | agent-behavior | unclear-doc | duplicate-truth | runtime-bug
  severity: high           # critical | high | medium | low
  description: |
    What is wrong, what is expected, what is needed.
  discovered_by: "source-identifier"
  doc: "path/to/affected/file"
  parent_loop: "LOOP-NAME"
```

Machine contract: `ops/bindings/gap.schema.yaml`. Full schema: `docs/governance/OUTPUT_CONTRACTS.md` section 2.

### Proposal Manifest

```yaml
proposal: CP-YYYYMMDD-HHMMSS
agent: "agent-id"
created: "YYYY-MM-DDTHH:MM:SSZ"
status: pending
description: "One-line summary"
changes:
  - action: create         # create | modify | delete
    path: "relative/path"
    reason: "Why"
```

Machine contract: `ops/bindings/proposals.lifecycle.yaml`. Full schema: `docs/governance/OUTPUT_CONTRACTS.md` section 3.

### Agent Result Block

```yaml
STATUS: ok                 # ok | blocked | failed
ARTIFACTS:
  - path/to/file
OPEN_LOOPS: []             # Non-empty if STATUS != ok
NEXT: "Recommended next action or none"
```

Machine contract: `docs/core/AGENT_OUTPUT_CONTRACT.md`.

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
  - D62 git remote parity (prevents origin/github "split brain" histories).

## Proposal Queue Hygiene

Change proposals (`mailroom/outbox/proposals/CP-*`) follow a governed lifecycle defined in `ops/bindings/proposals.lifecycle.yaml`.

**When to submit a proposal:** Any multi-file or cross-surface change. Single read-only or single-file mutations can use `cap run` directly.

**When to supersede:** Run `proposals.supersede <CP> --reason "why"` when a proposal's changes are obsolete, already applied via another path, or replaced by later work.

**When to archive:** Run `proposals.archive` periodically (D83 tracks queue health). Applied proposals are archived after 3 days, superseded after 3 days.

**Queue ownership:** Terminal C control plane owns queue hygiene. `proposals.status` shows health + SLA breaches.

**Valid statuses:** `draft` → `pending` → `applied` | `superseded` | `draft_hold` | `read-only` | `invalid`

**Draft hold:** Intentionally deferred proposals must have `owner`, `review_date`, and `hold_reason`. These are excluded from pending counts but tracked for review.

## Anti-Stash Policy (Gap Lifecycle)

Every open gap in `operational.gaps.yaml` must be linked to an active loop (`parent_loop`).

- **No standalone gaps older than 7 days.** If a gap cannot be loop-linked within 7 days, it must be either: (a) linked to a new or existing loop, or (b) explicitly closed as an accepted deferral with owner/date recorded in `notes`.
- **Accepted deferrals** are policy exceptions recorded as `status: closed` with explicit acceptance context in `notes` (owner, date, rationale). They still require periodic review (D58 freshness).
- **`gaps.status` flags orphans and standalone gaps.** Zero orphans and zero unlinked standalone gaps is the target state.
- **Report-and-execute, not report-and-park.** Discovering a gap means registering it AND creating the loop to fix it. Gaps without execution plans are stashed findings.

## Common Causes Of "Non-Uniform Workflow"

- Work started without any loop anchor. Worktrees are optional (committing directly to main is fine), but every non-trivial change should have a loop scope for traceability. Without one you get "floating WIP": no scope anchor and no session log.
- Multiple terminals mutating git concurrently (branches/worktrees/merges in parallel). This creates stale worktrees, branch confusion, and occasional unexpected commits. The coarse git lock in ops commands helps, but ad-hoc git in multiple terminals can still bypass it. **Default rule:** if multiple terminals/agents may be active, treat the repo as read-only and use mailroom-gated writes (change proposals).
- Remote split brain (origin vs github not aligned). Agents base branches off different tips, so "truth" diverges and merges become messy. D62 is specifically to stop that.
- Loop closeout not consistently done. Without updating the loop scope with receipts and closing it, the next agent can't tell what's already proven and repeats work. D61 + `agent.session.closeout` is the mechanism meant to prevent this.
- Two repos, two contracts (`agentic-spine` vs `workbench`). If workbench changes aren't tied back to a spine loop (or vice versa), you get coordination gaps even when each repo is individually clean. Use `RUNWAY_TOOLING_PRODUCT_OPERATING_CONTRACT_V1.md` to declare write ownership and repo sequence up front.

### Codex Worktree Hygiene

When using codex worktrees (`.worktrees/codex-*`):

1. **Create** — branch from `origin/main` (fetch first): `git worktree add .worktrees/<name> -b codex/<name> origin/main`
2. **Base** — never stack codex branches without an explicit `--base` in the PR; rebase before opening PRs.
3. **Proof** — `git status` must be clean inside the worktree; D48 fails `spine.verify` on dirty worktrees.
4. **Retire** — after merge, remove immediately: `ops close loop <LOOP_ID>` or `git worktree remove .worktrees/<name>`; D48 flags merged/dirty/orphaned worktrees and orphaned stashes.

---

## Quick Checklist

### Desktop
- [ ] In spine repo
- [ ] Secrets gating verified
- [ ] Session bundle reviewed (`SESSION_PROTOCOL`, `brain/README`, `GOVERNANCE_INDEX`)
- [ ] Codex worktrees pruned (D48)
- [ ] Open loops recorded
- [ ] Receipts generated for work

### Mobile / Remote
- [ ] Environment stated explicitly
- [ ] Current state obtained (operator paste or bridge query)
- [ ] All outputs use output contract YAML blocks
- [ ] Gap IDs marked `GAP-OP-NNN` where unknown
- [ ] Handoff block produced for desktop ingestion
