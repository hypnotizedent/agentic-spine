---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-18
scope: dream-system-canonical-product-brief
---

# The Dream System

**What it is**: A self-governing agentic infrastructure where autonomous agents can safely, repeatably, and consistently build, deploy, monitor, and improve real software products.

**Status**: Operationally real. 48 days old (January 29 – March 18, 2026), 4,768 commits, 394 gates, 702 capabilities, 1,523 gap records.

---

## The Three-Sentence Vision

Build a system where an autonomous agent can be handed a product spec, scaffold the entire infrastructure, implement it, test it, deploy it, monitor it, and detect/fix drift — all without human intervention except approval gates. Make that system reproducible, auditable, and safe enough to run autonomously at 3am. Kill every pattern that requires a human to remember 8 things instead of 1.

---

## How Spine + Workbench Function as the Product

### Spine: The Governance Runtime
**Path**: `/Users/ronnyworks/code/agentic-spine`

The control plane. Every cap run produces a receipt. Every gate check is auditable. Every gap is tracked to resolution. The verify command is the system's health signal.

**Core surfaces**:
- `ops/capabilities.yaml` — 702 named, audited actions the system can take
- `ops/bindings/gate.registry.yaml` — 394 rules (94 active) enforced automatically
- `ops/bindings/operational.gaps.yaml` — 1,523 problems tracked, 1,315 resolved
- `surfaces/verify/drift-gate.sh` — Master verify orchestrator
- `.githooks/pre-commit` — 114-line commit gate (3 guards)
- `.claude/hooks/session-entry-hook.sh` — 372-line agent enrollment surface

**What makes it governance**: Receipts on everything. Gates as social contracts. Gap lifecycle from discovery to resolution. Mailroom orchestration for agent coordination.

### Workbench: The Operator Runtime
**Path**: `/Users/ronnyworks/code/workbench`

The human-facing surface. Raycast scripts for quick actions. SSH targets with LAN/Tailscale fallback. MCP servers that expose spine capabilities to Claude. Scripts that wrap spine capability runs.

**Core surfaces**:
- `.mcp.json` — MCP server config for Claude integrations
- `scripts/agents/` — Agent scripts for domain automation
- `.spine-link.yaml` — Formal binding to spine governance
- `infra/compose/mcpjungle/servers/` — MCP server definitions (canonical authority)

**What makes it operator-facing**: Workbench makes spine's capabilities accessible to a human operator. Spine makes the operator's intentions auditable and reproducible.

**Together they are the product**: When an agent runs a spine capability through a workbench MCP server, the entire chain from "human intent" to "infrastructure action" is documented.

---

## Why Governed Product Repos Prove Success

### mint-modules: The Best Example
**Path**: `/Users/ronnyworks/code/mint-modules`
**Age**: 13 days (created March 5, 2026)
**Status**: Production e-commerce platform, 19 modules

**What makes it proof**:
1. **Born already governed**: Gitea CI with staged-secrets enforcement from day 1
2. **Module contract pattern**: 19 `module.contract.yaml` files declaring lifecycle status (`runtime_active`, `future_horizon`, `blocked_on_order_truth`)
3. **Spine-link binding**: `.spine-link.yaml` establishes formal governance bundles (docker.compose.parity, deploy.health.contract, endpoint.liveness)
4. **Only consumer repo with CI**: Gitea workflows run checks that spine declared
5. **MCP integration**: Mint MCP servers (mint-pricing, mint-suppliers) registered in spine's MCP runtime contract

**The pattern**: Create the contract → scaffold the governance → enforce from day 1 → lifecycle-manage modules through declared status → cross-register with spine MCP.

**Why this proves spine-built success**: In 13 days, spine enabled a full 19-module platform to be governed without inventing governance from scratch. The scaffold worked. The pattern transferred. The new thing was born already inside the fence.

### Other Governed Repos

**ronny-products** (`/Users/ronnyworks/code/ronny-products`):
- 3 parked products with `app.contract.yaml` governance
- Pre-commit hook chains: shape-lock → content-lock → dna-lock
- Each product contract binds to spine loops (e.g., `parent_loop: LOOP-INBOX-SHIELD-PLANNING-20260302`)

**agentic-foundation** (`/Users/ronnyworks/code/agentic-foundation`):
- Pure infrastructure source library
- `.spine-project.yaml` declares `governance_authority: ~/code/agentic-spine`
- No governance invented — everything delegated to spine

---

## Session Entry Hook and Live Gates: First-Class Features

### Session Entry Hook: Agent Admission Control
**Path**: `.claude/hooks/session-entry-hook.sh`
**Size**: 372 lines
**Trigger**: UserPromptSubmit (every Claude Code session start)

**What it enforces**:
1. **Worktree isolation (D140)**: Rejects agents in managed worktree prefixes unless `OPS_WORKTREE_IDENTITY` is set
2. **Terminal role validation**: Checks `terminal.role.contract.yaml` to establish agent role context
3. **Multi-agent detection**: Scans `mailroom/state/sessions/` for other active agents (4-hour TTL via `SPINE_SESSION_TTL`)
4. **Dynamic governance brief**: Delivers current governance context (active gates, open gaps, pending proposals)
5. **Proposal queue gating**: Alerts if >5 pending proposals in `mailroom/outbox/proposals/`

**Why it's a product feature**: Without this hook, an agent starting a session has no automatic context about the governance state. With it, every agent is enrolled before executing a single command. This is the **first line of agent governance**.

**Related contracts**:
- `ops/bindings/terminal.role.contract.yaml`
- `ops/bindings/role.runtime.control.contract.yaml`
- `ops/bindings/worktree.session.isolation.yaml` (D140 policy)

### D399: Live External-State Enforcement
**Path**: `surfaces/verify/d399-microsoft-mint-customer-mailbox-canonical-lock.sh`
**Size**: 560 lines (Python+Bash hybrid)
**Trigger**: Pre-push gate on every push to main

**What it checks** (14 live Microsoft API calls):
1-4: Team/info mailboxes exist + settings match contract (shared=true)
5-6: Redirect rules absent from info/ronny mailboxes
7-8: Recent inbox (250 messages) free of duplicates + shadow copies
9-14: Microsoft capability commands only use `microsoft-cap-exec` path

**Why it's a product feature**: This is not a static file check — it's a **LIVE API call to Microsoft on every push to main**. This is the current frontier of spine governance: gates that reach into live production systems before they allow a merge.

**What it proves**: The system can enforce consistency between declared contracts (`communications.providers.contract.yaml`) and live production state (Microsoft Exchange/Graph API) before code hits main.

---

## Authority → Generator → Projection → Gate

This is the core operational pattern that makes the system self-governing.

### Authority
**What it is**: The single canonical source of truth for a concern.
**Example**: `docs/governance/SERVICE_REGISTRY.yaml` is authority for all services across all VMs.

**Rules**:
- Exactly one file per concern is `state: authoritative`
- All other related files are either `state: projection` or `state: tombstoned`
- Authority files are tracked in `ops/bindings/authority.concerns.yaml`

### Generator
**What it is**: A capability that reads authority and produces projections.
**Example**: `service.registry.projection.build` reads `SERVICE_REGISTRY.yaml` and generates `services.health.yaml` and `docker.compose.targets.yaml`.

**Rules**:
- Generators must write `# GENERATED — DO NOT EDIT` headers
- Generators must populate `generated_at_utc` timestamps
- Generators are idempotent (same input → same output)

### Projection
**What it is**: A derived file that should never be hand-edited.
**Example**: `services.health.yaml` is a projection of `SERVICE_REGISTRY.yaml`.

**Rules**:
- All projections must have `authority_state: projection` marker
- All projections must be registered in `domain.projection.contract.yaml`
- Pre-commit should block staged edits unless `OPS_PROJECTION_OVERRIDE=1`

### Gate
**What it is**: An enforcement script that checks authority ↔ projection consistency.
**Example**: D275 checks that authority concerns match projections.

**Rules**:
- All gates are registered in `gate.registry.yaml` (D85 enforces parity)
- Gates run via `verify.core.run` or in pre-commit/pre-push hooks
- Gate failure blocks commits/merges (unless override env vars are set)

---

## What Kinds of Files Should Never Be Hand-Edited Again

### Current Projections (Already Generated)
- `ops/bindings/services.health.yaml` (projection of `SERVICE_REGISTRY.yaml`)
- `ops/bindings/docker.compose.targets.yaml` (projection of `SERVICE_REGISTRY.yaml`)
- `ops/bindings/terminal.role.contract.yaml` (projection of `agents.registry.yaml`)
- `CLAUDE.md` gate metadata block (projection of `gate.registry.yaml`)
- `AGENTS.md` gate metadata block (projection of `gate.registry.yaml`)
- `ops/bindings/backup.posture.snapshot.yaml` (projection of `backup.inventory.yaml`)
- `ops/bindings/internet.asset.registry.projected.yaml` (projection of `internet.asset.registry.yaml`)
- `ronny-products/EXECUTION_BOARD.md` (projection of repo-local `app.contract.yaml`)

### Should Become Projections (Not Yet Generated)
- `ops/bindings/gate.execution.topology.yaml` — should derive from `gate.registry.yaml`
- `ops/bindings/intake.lifecycle.contract.yaml` domain entries — should derive from `capabilities.yaml`
- `ops/bindings/capability_map.yaml` — should derive from `capabilities.yaml`
- `agentic-foundation/docs/agents/*.contract.md` (17 files) — now projection-marked compatibility stubs; full generation is still blocked on explicit supplemental authorities

### Recognition Rule
If the authority changes, does this doc update automatically?
- **YES** → it's a projection backed by a generator. ✅ Good.
- **NO** → it's a static doc pretending to be current. ❌ Fix it.

---

## The Gap Registry as Institutional Memory

**File**: `ops/bindings/operational.gaps.yaml`
**Size**: ~15,000 lines, 1,523 entries
**Schema**: Enforced by D332 (gate checking `gap.schema.yaml` v1.1)

**What makes it special**: 1,523 filed gaps with 1,315 resolved is not technical debt — it is a record of 1,315 improvements. The gap registry IS the institutional memory of the system's own evolution. No team of 10 human engineers would have that level of traceability in 48 days.

**Gap lifecycle**:
1. **File**: `./bin/ops cap run gaps.file --id auto --type ... --severity ... --description "..." --discovered-by "..." --doc "..."`
2. **Claim**: `./bin/ops cap run gaps.claim --id GAP-OP-XXX --action "desc"`
3. **Close**: `echo "yes" | ./bin/ops cap run gaps.close --id GAP-OP-XXX --status fixed --fixed-in "ref"`

**Why `--id auto` matters**: Prevents collisions with concurrent agents. Manual gap ID assignment is unreliable.

**Lock contention**: Back-to-back `gaps.file` calls need `sleep 5` between them (GAP-OP-1088).

---

## Receipts and Evidence

**Receipts**: Every cap run writes a receipt to `~/.evidence/spine/sessions/RCAP-*/receipt.md`.

**Verify reports**: Gate run results go to `~/.evidence/spine/verify/`.

**Loop closeouts**: Loop lifecycle evidence goes to `~/.evidence/spine/loop-closeouts/`.

**What this enables**: You can replay what happened. An agent that goes off-rails leaves an evidence trail. Work can't silently disappear.

---

## Why This Makes Autonomous Product Building Safer

The safety comes from 4 properties:

1. **Receipts on everything**: Every cap run writes a receipt. An agent that goes off-rails leaves an evidence trail. You can replay what happened.

2. **Gates as social contracts**: When an agent creates a new gate, capability, or domain, the gate system will catch any missed surfaces at next verify. The agent can't "partially do it" without detection.

3. **Gap lifecycle**: An agent that files a gap creates a resolvable work item. The gap system tracks it through to closure. Work can't silently disappear.

4. **Mailroom orchestration**: Agents communicate through the mailroom (inbox/outbox model). No agent acts on stale context — the mailroom is the session coordination surface.

**The practical result**: You can tell Claude "build inbox-shield" and it will create the product directory, the app.contract.yaml, the docker-compose, the implementation, file gaps for anything it can't complete, and register it with spine — all in one loop. Then future agents can see the gap trail and know exactly what work remains.

---

## The Core Problem and the Solution

### The Problem
You built a detection system, not a prevention system.

When you add a new domain, you must update 8 files manually. You get 5 right, miss 3. Gates catch the 3 missing ones. You spend a session backfilling. Repeat next week.

72% of all commits (3,416 out of 4,768) touch `ops/bindings/`. Most of that is backfill — making things consistent that should have been generated.

### The Solution
**Generate the derivative files**: `gate.execution.topology.yaml`, `intake.lifecycle.contract.yaml`, and `capability_map.yaml` should all be computed from the 5 authority files. Not hand-maintained.

**Complete the scaffold**: `generate-scaffold.sh --type gate` must produce ALL 8 required entries atomically. If the scaffold is complete, consistency is automatic.

**Gate the creation path**: Instead of 90 gates checking "is everything consistent?", have 1 gate checking "was the scaffold used?" If the scaffold is complete, consistency is guaranteed.

---

## The 5 Files That Own Everything

If you could only keep 5 files, these would be:

1. **ops/capabilities.yaml** — What the system can do (702 entries)
2. **ops/bindings/gate.registry.yaml** — What the system enforces (394 entries, 94 active)
3. **ops/bindings/master.inventory.registry.yaml** — What physical/logical assets exist
4. **ops/bindings/operational.gaps.yaml** — What is broken (1,523 entries, 19 open)
5. **spine.schema.conventions.yaml** — How YAML files must be structured

Everything else derives from these 5 or is runtime state.

---

## Smallest Canon Stack a New Agent Must Understand

1. Read `AGENTS.md` (runtime contract)
2. Read `docs/governance/SPINE.md` (operating rules)
3. Run `./bin/ops cap run session.start` (orientation)
4. Know that `cap run` commands write receipts to `~/.evidence/`
5. Know that `verify.core.run` is the green/red signal for the whole system
6. Never hand-edit files marked `generated_only: true`
7. If filing a gap: `gaps.file --id auto`
8. If closing a gap: `gaps.close --id GAP-OP-XXX`

---

## Next Evolution: Projection-First Architecture

**Current state**: 8 files manually touched per domain addition, 72% of commits are backfill.

**Target state**: 1 command produces all 8 required surfaces atomically.

**Migration path**: See `DREAM_SYSTEM_EXECUTION_BOARD.yaml` for ordered backlog of "docs that should be executable."

---

## References

- Authority concern map: `ops/bindings/authority.concerns.yaml`
- Domain projection contract: `ops/bindings/domain.projection.contract.yaml`
- Execution backlog: `docs/governance/DREAM_SYSTEM_EXECUTION_BOARD.yaml`
- Forensic reports: `~/.evidence/spine/verify/CODE_DREAM_SYSTEM_FORENSIC_20260318.md`
