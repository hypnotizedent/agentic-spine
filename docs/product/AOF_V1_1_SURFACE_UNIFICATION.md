---
status: approved
owner: "@ronny"
last_verified: 2026-02-18
scope: aof-v1.1-surface-unification
parent_gap: GAP-OP-627
parent_loop: LOOP-AOF-V1-1-SURFACE-UNIFICATION-20260217
---

# AOF v1.1 — Surface Unification Design

> Architectural proposal to eliminate surface sync sprawl and establish a single delivery
> layer for governance context, agent tools, and slash commands across all consuming surfaces.

## Status

**APPROVED** — Design reviewed and approved 2026-02-17. Implementation sequenced as Step 1 → 2 → 3.

**Implementation Progress:**
- Step 1 (MCP Gateway): **DELIVERED** — `ops/plugins/mcp-gateway/bin/spine-mcp-serve` live, `.mcp.json` cutover to gateway-first (2026-02-18)
- Step 2 (Agent Registry V2): **DELIVERED** — Schema extended, `agent.info` + `agent.tools` caps registered, registry population complete (2026-02-18; extended 2026-02-21 with communications-agent)
- Step 3 (Dynamic Context): **NOT STARTED** — Pending D65-v2 design

## Problem

AOF v1.0 built surfaces incrementally. Each new consumer (Claude Code, Claude Desktop,
OpenCode, Mailroom Bridge) got its own configuration, its own copy of governance docs, and
its own MCP server wiring. The result:

| What | Source of Truth | Copies Maintained | Sync Mechanism |
|------|----------------|-------------------|----------------|
| Governance brief | `AGENT_GOVERNANCE_BRIEF.md` | 3 (AGENTS.md, CLAUDE.md, OPENCODE.md) | `sync-agent-surfaces.sh` |
| Slash commands | `surfaces/commands/*.md` | 3 (Claude Code, OpenCode, Codex) | `sync-slash-commands.sh` |
| MCP servers | No single source | 4 (`spine/.mcp.json`, `workbench/.mcp.json`, Claude Desktop config, OpenCode config) | Manual |
| Agent contracts | `ops/agents/*.contract.md` | 1 per agent (prose-only) | Manual |
| Startup block | `AGENT_GOVERNANCE_BRIEF.md` | 3 embeds | `sync-agent-surfaces.sh` |

**Cost of the current model:**
- Every governance brief edit requires running a sync script + verifying D65 parity
- Every new agent requires: `.contract.md` + registry entry + MCP config in N surfaces
- No surface can programmatically query "what tools does agent X have?"
- New surfaces (future: Cursor, Windsurf, Codex cloud) multiply the sync burden linearly

## Proposal: Three Steps

### Step 1 — Unified Spine-MCP Gateway

**What:** Build a single MCP server that wraps the entire capability registry as MCP tools.

**Architecture:**
```
spine-mcp-gateway (Python3, stdlib-only, MCP stdio transport)
    │
    ├── tool: cap_run(name, args)        → ./bin/ops cap run <name> <args>
    ├── tool: cap_list(filter?)           → ./bin/ops cap list [--domain X]
    ├── tool: agent_info(agent_id)        → ./bin/ops agent info <id>
    ├── tool: agent_route(keywords)       → ./bin/ops agent route <keywords>
    ├── tool: spine_context()             → governance brief + live state
    ├── tool: gap_file(...)               → ./bin/ops cap run gaps.file ...
    ├── tool: loop_status()               → ./bin/ops cap run loops.status
    │
    └── (domain agent tools delegated through cap_run)
         ├── finance: list_accounts → cap_run("finance.list.accounts")
         ├── ha: entity_list → cap_run("ha.entity.list")
         └── immich: status → cap_run("immich.status")
```

**Configuration in any surface:**
```json
{
  "mcpServers": {
    "spine": {
      "command": "/Users/ronnyworks/code/agentic-spine/bin/ops",
      "args": ["mcp", "serve"]
    }
  }
}
```

One line. Every surface. All 299+ capabilities available as tools. New caps auto-appear
without touching any surface config.

**Implementation:**
- New plugin: `ops/plugins/mcp-gateway/bin/spine-mcp-serve`
- New CLI subcommand: `./bin/ops mcp serve` (routes to plugin)
- Python3 MCP stdio server (same pattern as existing `rag-mcp-server`)
- Safety enforcement: read-only caps auto-approved, mutating/destructive caps require
  the same approval flow as CLI
- Secrets: injected server-side via `infisical-agent.sh` (callers never see tokens)

**What gets retired:**
- `spine/.mcp.json` (spine-rag absorbed into gateway)
- `workbench/.mcp.json` (media/finance agents absorbed via cap delegation)
- Per-surface MCP blocks in Claude Desktop config and OpenCode config
- MCPJungle config-only server JSONs (replaced by cap wiring)

**What stays:**
- Standalone MCP servers with complex state (e.g., Docker MCP, GitHub MCP) remain
  independent — the gateway doesn't replace servers that have their own protocol needs
- `rag-mcp-server` implementation gets reused inside the gateway (not rewritten)

**New capabilities required:**
- `spine.mcp.serve` — start the MCP gateway (read-only, auto-approval)
- `agent.info` — query agent registry by ID (read-only)
- `agent.route` — keyword-based agent routing (read-only)
- `spine.context` — see Step 3

**Estimated scope:** ~300 lines of Python (server) + ~50 lines of shell (CLI wiring) +
capability registration.

---

### Step 2 — Queryable Agent Registry

**What:** Extend `agents.registry.yaml` with machine-queryable fields so agent contracts
become data, not just prose.

**Current schema (abbreviated):**
```yaml
- id: finance-agent
  domain: finance
  status: active
  implementation_repo: workbench
  implementation_path: agents/finance/
```

**Proposed schema extension:**
```yaml
- id: finance-agent
  domain: finance
  status: active
  implementation_repo: workbench
  implementation_path: agents/finance/
  # --- NEW FIELDS ---
  mcp_tools:
    - name: list_accounts
      safety: read-only
      description: "List Firefly III accounts with balances"
    - name: list_transactions
      safety: read-only
      description: "Query transactions by date range"
    - name: search_documents
      safety: read-only
      description: "Search Paperless-ngx documents"
  capabilities:
    - finance.stack.status
    - secrets.bundle.verify
  write_scope:
    - ops/plugins/finance/
  gates:
    - D-TBD
  endpoints:
    firefly:
      host: "100.76.153.100"
      port: 8080
      auth: infisical/finance/prod/FIREFLY_PAT
    paperless:
      host: "100.76.153.100"
      port: 8000
      auth: infisical/finance/prod/PAPERLESS_API_TOKEN
```

**New CLI commands:**
```bash
./bin/ops agent list                    # all agents with status
./bin/ops agent info finance-agent      # full detail (machine + human readable)
./bin/ops agent tools finance-agent     # just the tool inventory
./bin/ops agent route "bank statement"  # keyword → agent resolution
```

**Migration path:**
1. Add new fields to registry schema (backward-compatible — existing fields unchanged)
2. Populate fields for all registered agents from their `.contract.md` files
3. `.contract.md` files become supplementary prose (not deleted, but no longer authoritative
   for tool/endpoint data)
4. Gateway (Step 1) reads `agents.registry.yaml` to dynamically expose per-agent tools

**Estimated scope:** Schema extension + 10 agent registry updates + CLI plugin (~100 lines
shell).

---

### Step 3 — Dynamic Context Delivery (`spine.context`)

**What:** Replace static governance brief embeds with a capability that serves the current
brief + live state on demand.

**Capability output:**
```yaml
governance_brief_version: "2026-02-17"
governance_brief: |
  (full text of AGENT_GOVERNANCE_BRIEF.md)
active_state:
  open_loops: 3
  open_gaps: 1
  pending_proposals: 5
  policy_preset: balanced
terminal_roles:
  - SPINE-CONTROL-01 (this session)
agent_summary:
  - communications-agent: registered (10 communications surfaces)
  - finance-agent: active (13 tools)
  - home-assistant-agent: active (37 caps)
  - immich-agent: registered (5 caps)
startup_block: |
  (rendered startup commands)
```

**How surfaces consume it:**

*Claude Code* — `session-entry-hook.sh` calls `./bin/ops cap run spine.context` instead of
reading + embedding `AGENT_GOVERNANCE_BRIEF.md` directly. The hook becomes a thin wrapper.

*Claude Desktop* — The Claude AI skill (`surfaces/claude-ai-skill/SKILL.md`) calls
`spine.context` via MCP gateway tool on session start.

*OpenCode* — `OPENCODE.md` startup block calls `spine.context`. Context is live, not
copy-pasted.

**D65 evolution:**

| D65 v1.0 (current) | D65 v2.0 (proposed) |
|---------------------|---------------------|
| AGENTS.md and CLAUDE.md must contain exact copy of governance brief | AGENTS.md and CLAUDE.md contain thin shim: "call `spine.context` on entry" |
| `sync-agent-surfaces.sh` enforces parity | Gate validates that shim calls `spine.context` (not embed parity) |
| Edit brief → run sync → verify D65 | Edit brief → done (served dynamically) |

**What gets retired:**
- `ops/hooks/sync-agent-surfaces.sh` (no more embed sync)
- `ops/hooks/sync-slash-commands.sh` (commands served via MCP gateway)
- D65 embed-parity check (replaced by D65-v2 shim-presence check)
- ~120 lines of embedded governance text removed from AGENTS.md
- ~120 lines of embedded governance text removed from CLAUDE.md

**What stays:**
- `AGENT_GOVERNANCE_BRIEF.md` remains the single source file
- `AGENTS.md` and `CLAUDE.md` still exist (thin shims + startup block)
- The brief content doesn't change — only the delivery mechanism does

**Estimated scope:** New capability script (~80 lines shell) + hook refactor + D65-v2 gate
script + shim updates to AGENTS.md/CLAUDE.md/OPENCODE.md.

---

## Sequencing and Dependencies

```
Step 1 (gateway)  ──────────────────►  Step 2 (registry)  ────►  Step 3 (context)
                                        │                          │
                                        │ registry feeds           │ context cap
                                        │ gateway tool list        │ served via gateway
                                        └──────────────────────────┘
```

Each move is independently shippable and valuable:
- **Step 1 alone** eliminates per-surface MCP config sprawl
- **Step 1 + Step 2** adds programmatic agent discovery
- **Step 1 + Step 2 + Step 3** completes the vision (zero-sync surfaces)

## Impact Analysis

### Files Created
| File | Purpose |
|------|---------|
| `ops/plugins/mcp-gateway/bin/spine-mcp-serve` | MCP gateway server |
| `ops/plugins/agents/bin/agent-info` | Agent query CLI |
| `ops/plugins/agents/bin/agent-route` | Agent routing CLI |
| `ops/plugins/context/bin/spine-context` | Context delivery cap |
| `surfaces/verify/d65-v2-context-delivery-check.sh` | Evolved D65 gate |

### Files Modified
| File | Change |
|------|--------|
| `ops/capabilities.yaml` | Register new caps (spine.mcp.serve, agent.info, agent.route, spine.context) |
| `ops/bindings/capability_map.yaml` | Navigation entries for new caps |
| `ops/bindings/agents.registry.yaml` | Extended schema (mcp_tools, capabilities, write_scope, gates, endpoints) |
| `AGENTS.md` | Thin shim (Step 3 only) |
| `CLAUDE.md` | Thin shim (Step 3 only) |
| `bin/ops` | Add `mcp serve` subcommand routing |
| `surfaces/verify/d65-agent-briefing-sync-lock.sh` | Evolve to D65-v2 (Step 3 only) |

### Files Retired
| File | Reason |
|------|--------|
| `ops/hooks/sync-agent-surfaces.sh` | Replaced by dynamic context (Step 3) |
| `ops/hooks/sync-slash-commands.sh` | Commands served via MCP gateway (Step 1) |
| `.mcp.json` (spine root) | Absorbed by gateway |
| MCPJungle config-only JSONs | Absorbed by gateway cap delegation |

### Gates Affected
| Gate | Change |
|------|--------|
| D65 | Evolves from embed-parity to shim-presence check (Step 3) |
| D67 | Unchanged — new caps still need both yaml registrations |
| D63 | Unchanged — monolith paths still enforced |

## Acceptance Criteria

1. `./bin/ops mcp serve` starts and passes MCP protocol handshake
2. Claude Code with single `spine` MCP server config can call any existing capability
3. `./bin/ops agent info finance-agent` returns structured tool/endpoint data
4. `./bin/ops agent route "bank transactions"` resolves to `finance-agent`
5. `./bin/ops cap run spine.context` returns governance brief + live state
6. All existing drift gates pass after each move
7. No existing capability invocations break (`./bin/ops cap run <name>` unchanged)
8. Net file count delta: negative (more retired than created)

## Non-Goals

- Replacing standalone MCP servers that have complex protocol needs (Docker, GitHub)
- Changing the AOF policy runtime (presets, knobs, resolve-policy.sh)
- Modifying the receipt ledger format
- Altering the capability safety/approval model
- Removing `.contract.md` prose docs (they become supplementary, not deleted)

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Gateway becomes single point of failure | Fallback: direct `./bin/ops cap run` still works, gateway is additive |
| MCP protocol changes upstream | Python stdlib-only implementation, minimal protocol surface |
| Agent registry schema migration breaks existing tooling | Additive fields only, no removal of existing fields |
| D65-v2 rollout leaves surfaces with stale embeds | Staged: keep embeds until Step 3 is verified, then cut over |
