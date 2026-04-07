---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-27
scope: session-entry
---

# Session Protocol (Spine-native)

> **Purpose:** Entry point for every agent working with the agentic-spine,
> regardless of device or surface (desktop CLI, mobile, remote/tailnet).
>
> **Canonical output schemas:** this document's Output Contracts section plus the machine contracts named there.

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

1. Confirm you are in the spine repo (`cd ~/code/agentic-spine`).
2. Read `docs/governance/SPINE.md` for the minimal operating contract. This file carries the session-entry and environment-specific behavior.
3. For cross-repo parallel work, declare write ownership and repo sequence in the active loop scope before mutation.

### Execution Posture

Sessions operate in one of two postures:

- **`discover`** (default): Normal operation. New gaps, loops, and proposals may be created.
- **`converge`**: Closure-only mode. New gaps and loops are **mechanically blocked** at the authority bridge level. Allowed actions: close, defer, merge, narrow, reparent, supersede. Newly discovered issues go in the session receipt as observations, not in the registry.

To start a converge session:
```
./bin/ops cap run session.v3.attach -- --posture converge --allow-no-loop
```
Or export before attach: `export SPINE_EXECUTION_POSTURE=converge`

Break-glass override (per-command, not per-session):
```
SPINE_POSTURE_OVERRIDE_REASON="<reason>" ./bin/ops cap run gaps.file -- ...
```

Posture is visible in the session admission block and propagates through dispatch envelopes via the `execution_posture` field. See `ops/bindings/execution.posture.contract.yaml` for the full contract.

### Session steps

1. **Start the session**
   - Run `./bin/ops cap run session.v3.attach -- --allow-no-loop` — canonical terminal entry. It attaches governed context in one pass and is the only routine startup surface.
   - Run `./bin/ops cap run session.start full` only when explicitly requested for deep bootstrap diagnostics after attach.
   - Run `./bin/ops cap run session.start degraded` only for degraded bootstrap / recovery when startup dependencies are partially unhealthy; it is diagnostics-only and preserves checkout/worktree guards plus runtime state location hints.
   - If you need to touch secrets, source `~/.config/infisical/credentials` first.
   - Canonical nightly closeout SOP entrypoint: `./bin/ops cap run nightly.closeout -- --mode dry-run` then `./bin/ops cap run nightly.closeout -- --mode apply`.
2. **Start work**
   - Prioritize closing existing work (loops, gaps) before starting new work.
   - Use a 3-card intake before mutation work:
     - objective (single sentence)
     - done check (how completion will be verified)
     - first command (deterministic first execution step)
   - If the task mutates tracked repo surfaces, bootstrap or enter a managed worktree unless this is a bounded controller landing of one exact slice on root `main`.
   - If capability syntax is uncertain, run `./bin/ops cap show <capability>` before execution. Do not guess.
   - Discover capabilities with `./bin/ops cap list` when needed. Do not invent commands.
3. **Trace truth**
   - Query hierarchy: direct file read → `./bin/ops cap run rag.anythingllm.ask "<query>"` → `spine-rag` MCP → `./bin/ops cap run receipts.summary -- --domain none --days 7` → `./bin/ops cap run session.handoff.list --state active` → `./bin/ops cap run loops.status` / `./bin/ops cap run gaps.status` → `rg` fallback.
   - Before guessing remote paths, consult `ops/bindings/docker.compose.targets.yaml` and `ops/bindings/ssh.targets.yaml` first.
   - **Mailroom state is externalized**: `mailroom/state/` paths resolve to `$SPINE_STATE` (`~/code/.runtime/spine/state/`) via `spine_resolve_mailroom_path()`. The repo-local `mailroom/` directory is **forbidden** (D377/D396/D397). Always use `$SPINE_STATE/` for direct access or let the resolver handle `mailroom/state/` prefixed paths.
   - **Before any shop network change:** run `./bin/ops cap run network.shop.audit.status` (D54 enforces).
4. **Operate through the spine**
   - Every mutating command must go through `./bin/ops cap run <capability>` so receipts land in `~/code/.evidence/spine/sessions/`.
   - **Spine is the runtime environment.** Workbench file edits are allowed when a spine loop requires it.
   - **Root `main` is integration-only.** Root `main` is not a general mutation lane. Normal mutation belongs in managed worktrees.
   - **Bounded controller landing is the only root-main exception.** The only governed dirty root-main state is an explicit controller-owned `staged_only` landing window for one exact slice.
   - **`OPS_GOVERNED_MAIN_OVERRIDE=1` is only intentional-main override.** It does not bypass D48 or D150.
   - **Shared root-lane mutation is blocking contention.** Multiple terminals are independent only when they do not share the same root checkout, git index, or protected hotspot surfaces. Separate managed worktrees are the normal parallel model.
   - **Git authority:** Gitea (`origin`) is canonical operational truth; GitHub is publication-only.
   - **Downstream runtime extraction remains future work.** It is unrelated to this workflow rule.
   - **Impact-scoped docs:** for domain work, update only the domain runbook and create a receipt note with `./bin/ops cap run docs.impact.note <domain> <receipt_run_key>`.

### Execution Mode Decision Tree

| Scenario | Execution Mode |
|----------|---------------|
| **Canonical startup** | `./bin/ops cap run session.v3.attach -- --allow-no-loop` |
| LEGACY: deep diagnostics (only when attach fails) | `./bin/ops cap run session.start full` |
| LEGACY: degraded recovery (only when dependencies are unhealthy) | `./bin/ops cap run session.start degraded` |
| Tracked repo mutation / concurrent work | `./bin/ops cap run session.execution.lane.bootstrap ...` then mutate in the managed worktree |
| Single read-only query | `ops cap run` (auto-approval) |
| Single mutating action | `ops cap run` (manual approval) |
| Multi-step coordinated work | Open a loop, use proposal flow |
| Quick verify/status check | `ops cap run verify.run -- fast` |
| Post-domain-work verify | `ops cap run verify.run -- domain <domain>` |
| Release/nightly certification | `ops cap run verify.release.run` |
| Lifecycle nightly closeout | `ops cap run nightly.closeout -- --mode dry-run` → `ops cap run nightly.closeout -- --mode apply` |

### Verify Tiers

| Tier | When | Command | Time |
|------|------|---------|------|
| **Fast** | On-demand quick verify (or before high-risk changes) | `verify.run -- fast` | <60s |
| **Domain** | After domain work, before commit | `verify.run -- domain <domain>` | 1-5 min |
| **Full release** | Nightly / release only | `verify.release.run` | 10-15 min |

Network gates (infra health, backup checks, media stack) have Tailscale guards — they SKIP cleanly when VPN is disconnected instead of hanging or triggering login popups.

### Backlog Survival Bar

- Leave a backlog item open only when it has an owner, a parent loop (or explicit terminal disposition), and one concrete `next_action`.
- If work already landed, close the loop/gap/proposal in the same session instead of leaving a stale open artifact behind.
- If two active items describe the same outcome, merge to one survivor and close the duplicate with a note pointing at the survivor.
- If a proposal is past its review point and still unowned or inactive, supersede/archive it instead of preserving zombie backlog.

### After the session (Desktop)

- Store any learnings in `docs/reference/brain/memory.md` if that system is enabled.
- Close open loops with `./bin/ops loops close <loop_id>` before wrapping up.
- Always produce receipts for the commands you executed. Receipts live under `~/code/.evidence/spine/sessions/R*/receipt.md` and prove what you did.

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

**Canonical source:** this section and the machine contracts it names.

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

This inline schema is the canonical human contract for loop scope frontmatter.

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

Machine contract: `ops/bindings/gap.schema.yaml`.

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

Machine contract: `ops/bindings/proposals.lifecycle.yaml`.

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

All loop scope files in `$SPINE_STATE/loop-scopes/` (externalized runtime) MUST use one of these three values in their status field.

---

## What Keeps This Predictable (Gates + Governance)

- **Entry governance:** `AGENTS.md` + this `SESSION_PROTOCOL.md` define the canonical workflow: start in the spine repo, list open loops, do work via `./bin/ops cap run ...` / `./bin/ops run ...`, and close loops with receipts.
- **Loop engine:** `./bin/ops loops ...` + `$SPINE_STATE/loop-scopes/*.scope.md` are the shared coordination surface other agents can see.
- **Receipts + ledger:** `~/code/.evidence/spine/sessions/**/receipt.md` are the primary proof trail. The runtime ledger at `~/code/.runtime/spine/state/ledger.csv` is the canonical run-history index (externalized per `mailroom.runtime.contract.yaml`).
- **Drift gates (enforced by `spine.verify`):**
  - D42 code-path case lock (keeps `~/code/...` canonical, blocks drift like `~/Code/...`).
  - D48 worktree/root-lane hygiene (enforces managed-worktree default, integration-only root `main`, and lifecycle-aware cleanup/classification).
  - D34 loop ledger integrity (catches loop state inconsistencies).
  - D10/D31 logs/output sink locks (keeps output under mailroom, prevents home-root sinks).
  - D61 session-loop traceability freshness (forces periodic closeout discipline via `agent.session.closeout`).
  - D62 git remote authority (origin canonical operational truth; GitHub drift is informational outside publication).

## Proposal Queue Hygiene

Change proposals (`mailroom/outbox/proposals/CP-*`) follow the governed lifecycle defined in `ops/bindings/proposals.lifecycle.yaml`.

**Before submitting:** Run `./bin/ops cap run proposals.list` to check for existing proposals. Avoid duplicate work.

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

- Work started without any loop anchor or managed worktree. Root `main` is integration-only, so normal mutation belongs in managed worktrees and every non-trivial change should still have a loop scope for traceability. Without one you get floating WIP: no scope anchor, no session log, and no governed mutation lane.
- Multiple terminals touched the same root checkout, git index, or protected hotspot surfaces. That is blocking contention, not parallel work. Separate managed worktrees are fine; shared root-lane mutation is not.
- Optional GitHub drift (`origin` vs `github`) during non-release work. Canonical operational authority remains `origin`; GitHub drift is tolerated and repaired only for explicit publication.
- Loop closeout not consistently done. Without updating the loop scope with receipts and closing it, the next agent can't tell what's already proven and repeats work. D61 + `agent.session.closeout` is the mechanism meant to prevent this.
- Two repos, two contracts (`agentic-spine` vs `workbench`). If workbench changes aren't tied back to a spine loop (or vice versa), you get coordination gaps even when each repo is individually clean. Declare write ownership and repo sequence in the active loop scope up front.

### Managed Worktree Hygiene

When using managed worktrees:

1. **Create** — default lane flow is `ops wave start <WAVE_ID> --objective "..."` with auto workspace provisioning (`~/code/.runtime/spine/tmp/worktrees/<repo>/<WAVE_ID>`, branch `codex/<WAVE_ID>`). Manual `git worktree add` is fallback only.
2. **Base** — branch from `origin/main` (fetch first) when provisioning manual branches; never stack codex branches without explicit base intent.
3. **Classify before cleanup** — run `./bin/ops cap run worktree.lifecycle.reconcile -- --json` to see owner/state (`wave`, `loop`, `none`) and stale candidates.
4. **Retire explicitly** — lifecycle closeout first (`ops wave close`, `ops loops close`), then optional git cleanup. D48 now enforces lifecycle violations plus the integration-only root-main rule.
5. **Cleanup in phases** — run `worktree.lifecycle.cleanup` in strict order: `report-only` -> `archive-only` -> `delete` (token-gated).
6. **Auto-rehydrate missing paths** — if a lane worktree path is missing but branch exists, run `worktree.lifecycle.rehydrate` instead of creating ad-hoc roots.
7. **Land on root main only as an exception** — the controller may use root `main` only for one exact `staged_only` landing slice from a clean checkout. `OPS_GOVERNED_MAIN_OVERRIDE=1` marks intent; it does not bypass D48 or D150.

---

## Quick Checklist

### Desktop
- [ ] In spine repo
- [ ] Secrets gating verified
- [ ] Session bundle reviewed (`SESSION_PROTOCOL`, `brain/README`, `GOVERNANCE_INDEX`)
- [ ] Managed worktrees reconciled; root `main` clean unless in an explicit controller landing window
- [ ] Open loops recorded
- [ ] Receipts generated for work

### Mobile / Remote
- [ ] Environment stated explicitly
- [ ] Current state obtained (operator paste or bridge query)
- [ ] All outputs use output contract YAML blocks
- [ ] Gap IDs marked `GAP-OP-NNN` where unknown
- [ ] Handoff block produced for desktop ingestion
