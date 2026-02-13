---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
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

The domain-agent MCP bridge provides tool-call access to domain agents from Claude Code sessions via `.mcp.json`.

**Currently implemented:**
- `spine-rag`: RAG query/retrieve/health via `ops/plugins/rag/bin/rag-mcp-server` (registered in `.mcp.json`)

**Planned (not yet implemented):**
- Domain-agent MCP bridges for finance, media, n8n agents (requires per-agent MCP server adapters in workbench)
- Unified `agent.route` capability provides routing lookup but does not yet bridge MCP tool calls

**Routing capability:** `./bin/ops cap run agent.route <domain-or-keyword>` resolves to the correct agent using `ops/bindings/agents.registry.yaml` routing rules.

> **Important:** Do not claim full domain MCP parity in documentation. Only spine-rag is currently bridged. Domain agents are accessible via their own MCP servers (registered in MCPJungle), not yet via a unified spine MCP bridge.

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
