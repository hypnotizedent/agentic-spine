---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: agent-infrastructure-governance
github_issue: "#634"
---

# Agents Governance (SSOT)

Tracks: #634

## Purpose

Define the infrastructure contract for domain-specific agents in the agentic-spine: registry, lifecycle, discovery, and verification.

> **Scope note:** This document covers agent **infrastructure** (registry, contracts, discovery, verification).
> For **operational session rules** (commits, capabilities, drift gates), see [AGENT_GOVERNANCE_BRIEF.md](AGENT_GOVERNANCE_BRIEF.md).
> For **action boundary constraints** (what agents can/cannot do), see [AGENT_BOUNDARIES.md](AGENT_BOUNDARIES.md).

## Sources of Truth

> **Spine-native:** Agent governance lives inside this repo. Implementations may live in workbench; contracts and registry live here.

- **Registry (machine-readable):** `ops/bindings/agents.registry.yaml` — catalog of all domain agents with routing rules
- **Contracts:** `ops/agents/<agent-id>.contract.md` — per-agent ownership boundary (what it owns, what it defers)
- **Verification:** `surfaces/verify/agents_verify.sh` + D49 drift gate in `drift-gate.sh`
- Reference reports:
  - `docs/governance/AUDIT_VERIFICATION.md`
  - `docs/governance/_audits/AGENT_RUNTIME_AUDIT.md`
  - `docs/governance/CORE_AGENTIC_SCOPE.md`

## Agent Discovery

Every new Claude Code session receives agent discovery info via `generate-context.sh`:
- Section "Available Agents" lists registered agents with domains and descriptions
- Routing rules map problem keywords to the correct agent
- Agents consult `ops/bindings/agents.registry.yaml` for the full catalog

## Lifecycle
- **Register**: create `ops/agents/<id>.contract.md`, add entry to `agents.registry.yaml`, verify with `spine.verify`
- **Implement**: build agent tools in workbench (or other location per contract), update `implementation_status` in registry
- **Change**: update contract + registry entry, run `spine.verify`
- **Retire**: remove contract + registry entry, document rationale in session handoff

## MCP Bridge Scope

The runtime MCP bridge is unified through `spine` (`ops/plugins/mcp-gateway/bin/spine-mcp-serve`) and is the required server on Codex, Claude Desktop, and OpenCode per `ops/bindings/mcp.runtime.contract.yaml`.

**Gateway tools currently implemented:**
- `cap_list`, `cap_run` (governed capability execution)
- `rag_query`, `rag_retrieve`, `rag_health` (compat wrappers)
- `agent_list`, `agent_info`, `agent_tools`, `route_resolve` (registry-backed routing/discovery)

**Routing capability contract:**
- `./bin/ops cap run agent.route <domain-or-keyword>` for text lookup
- `./bin/ops cap run agent.route --json <domain-or-keyword>` for stable envelope output (`matched|not_found|error`) consumed by gateway `route_resolve`

Domain-specific MCP servers in workbench remain optional providers until delegated tool surfaces are fully absorbed by gateway policy.

## Control-Loop Glue Surfaces

`spine.control.*` is now available as the unified control-plane orchestration surface:

- `spine.control.tick` — read-only aggregated "what matters now" snapshot.
- `spine.control.plan` — read-only prioritized next actions with deterministic route targets (`capability|agent_tool`).
- `spine.control.execute` — mutating/manual execution for selected capability-backed actions with receipt linkage.

Execution writes the control-plane latest artifact under runtime-aware outbox path:

- `mailroom/outbox/operations/control-plane-latest.json`
- `mailroom/outbox/operations/control-plane-latest.md`

## Safety Rules
- No secrets in contracts or registry (names/paths only; never values)
- Verification output must not print secret content
- Agents must comply with WORKBENCH_CONTRACT (no watchers, no cron, no schedulers)
- Infrastructure concerns (compose, health, routing, secrets) stay in spine — agents own application layer only

## Verification
```bash
# Full drift gate suite (includes D49 agent discovery lock)
./bin/ops cap run spine.verify

# Agent-specific checks
./surfaces/verify/agents_verify.sh
```
Exit 0 = PASS, non-zero = FAIL
