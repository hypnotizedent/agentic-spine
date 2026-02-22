---
status: authoritative
owner: "@ronny"
generated_at: 2026-02-17
scope: aof-v1.1-surface-rolldown-plan
parent_loop: LOOP-AOF-V1-1-SURFACE-ROLLDOWN-20260217
design_source: docs/product/AOF_V1_1_SURFACE_UNIFICATION.md
---

# AOF v1.1 Surface Unification — Rolldown Execution Plan

> Vertical integration map for the approved AOF v1.1 surface unification design.
> Every workstream has a gap, a loop, target files, and compliance criteria.
> Agents can query this artifact to discover execution runway without memory or manual lists.

## WS -> GAP -> LOOP Mapping

| WS | Design Move | Gap | Severity | Loop | Status | Depends On |
|----|-------------|-----|----------|------|--------|------------|
| WS-2 | Move 1: Unified MCP Gateway | GAP-OP-636 | high | LOOP-SPINE-MCP-GATEWAY-V1-20260217 | active | — |
| WS-3 | Move 2: Queryable Agent Registry | GAP-OP-637 | medium | LOOP-AGENT-REGISTRY-SCHEMA-V2-20260217 | active | — |
| WS-4 | Move 3: Dynamic Context Delivery | GAP-OP-638 | medium | LOOP-DYNAMIC-CONTEXT-DELIVERY-V1-20260217 | active | — |
| WS-5 | Sync Artifact Retirement | GAP-OP-639 | medium | LOOP-SYNC-ARTIFACT-RETIREMENT-V1-20260217 | active | WS-4 |

**Predecessor artifacts (closed):**

| Artifact | Status |
|----------|--------|
| GAP-OP-627 (surface sync sprawl) | fixed |
| LOOP-AOF-V1-1-SURFACE-UNIFICATION-20260217 (design phase) | closed |
| `docs/product/AOF_V1_1_SURFACE_UNIFICATION.md` | approved |

## Target Files and Owning Surfaces

### WS-2: MCP Gateway (spine)

| File | Action | Surface |
|------|--------|---------|
| `ops/plugins/mcp-gateway/bin/spine-mcp-serve` | create | spine |
| `bin/ops` | modify | spine |
| `ops/capabilities.yaml` | modify | spine |
| `ops/bindings/capability_map.yaml` | modify | spine |

### WS-3: Agent Registry (spine)

| File | Action | Surface |
|------|--------|---------|
| `ops/bindings/agents.registry.yaml` | modify | spine |
| `ops/plugins/agent/bin/agent-info` | create | spine |
| `ops/plugins/agent/bin/agent-tools` | create | spine |
| `ops/capabilities.yaml` | modify | spine |
| `ops/bindings/capability_map.yaml` | modify | spine |

### WS-4: Dynamic Context (spine + workbench reference)

| File | Action | Surface |
|------|--------|---------|
| `ops/plugins/context/bin/spine-context` | create | spine |
| `ops/capabilities.yaml` | modify | spine |
| `ops/bindings/capability_map.yaml` | modify | spine |
| `ops/hooks/session-entry-hook.sh` | modify | spine |
| `AGENTS.md` | modify (thin shim) | spine |
| `CLAUDE.md` | modify (thin shim) | spine |
| `surfaces/verify/d65-agent-briefing-sync-lock.sh` | modify (D65-v2) | spine |
| `ops/bindings/gate.registry.yaml` | modify | spine |
| `workbench/dotfiles/opencode/OPENCODE.md` | modify (thin shim) | workbench (ref) |

### WS-5: Sync Retirement (spine)

| File | Action | Surface |
|------|--------|---------|
| `ops/hooks/sync-agent-surfaces.sh` | archive | spine |
| `ops/hooks/sync-slash-commands.sh` | archive | spine |
| `.mcp.json` | delete | spine |
| Gate scripts referencing sync hooks | modify | spine |

## Compliance Criteria

### Spine Compliance

| Criterion | Verification |
|-----------|-------------|
| All new capabilities registered | D67 (cap_map + capabilities.yaml parity) |
| No broken cap invocations | `./bin/ops cap run <name>` backward compat test |
| All gates pass post-merge | `verify.core.run` + `verify.domain.run aof` |
| Receipt trail intact | `receipts/sessions/` append-only |
| No secret values in code | D112 (secrets access pattern lock) |

### AOF Compliance

| Criterion | Verification |
|-----------|-------------|
| Policy runtime unchanged | D91 (product foundation artifacts) |
| Presets/knobs intact | `ops/bindings/policy.presets.yaml` untouched |
| Tenant schema intact | `ops/bindings/tenant.profile.schema.yaml` untouched |
| Version contract respected | `docs/product/AOF_PRODUCT_CONTRACT.md` version update if needed |

### Workbench Visibility

| Criterion | Verification |
|-----------|-------------|
| OPENCODE.md thin shim (WS-4) | Workbench repo update needed |
| MCPJungle config retirement (WS-5) | Workbench scope, documented but not mutated from spine |
| Finance-agent delegation (WS-2) | Verify cap_run path works for delegated tools |

## Agent Discoverability Checklist

After rolldown completion, agents can query:

| Query | Method | Available After |
|-------|--------|-----------------|
| "What capabilities exist?" | `./bin/ops cap list` or MCP `cap_list` | WS-2 (gateway) |
| "What does finance-agent do?" | `./bin/ops cap run agent.info finance-agent` | WS-3 (registry) |
| "What tools does HA agent have?" | `./bin/ops cap run agent.tools home-assistant-agent` | WS-3 (registry) |
| "Route me to the right agent" | `./bin/ops cap run agent.route "bank transactions"` | Already available |
| "What's the governance context?" | `./bin/ops cap run spine.context` | WS-4 (context) |
| "What loops/gaps are open?" | `./bin/ops status` | Already available |
| "Run a cap via MCP" | MCP tool `cap_run(name, args)` | WS-2 (gateway) |

## Execution Sequencing

```
WS-2 (gateway)  ──►  WS-3 (registry)  ──►  WS-4 (context)  ──►  WS-5 (retire)
 GAP-OP-636           GAP-OP-637             GAP-OP-638           GAP-OP-639
 HIGHEST PRIORITY     independent            independent          BLOCKED on WS-4
```

- WS-2 is first: highest leverage, unlocks MCP-based tool discovery for all surfaces
- WS-3 can run in parallel with or after WS-2
- WS-4 can run in parallel with or after WS-3
- WS-5 is strictly sequential: requires WS-4 completion before sync artifacts can retire

## Per-Workstream Acceptance Gates

### WS-2 Gate: MCP Gateway Ships
- [ ] `./bin/ops mcp serve` completes MCP handshake
- [ ] `cap_list` returns inventory via MCP
- [ ] `cap_run` executes read-only cap and returns output
- [ ] Core-8 + AOF domain gates pass

### WS-3 Gate: Registry Queryable
- [ ] `agent.info finance-agent` returns structured mcp_tools + endpoints
- [ ] `agent.tools home-assistant-agent` lists capabilities
- [ ] All 10 agents populated
- [ ] `agent.route` still works (backward compat)

### WS-4 Gate: Context Delivered Dynamically
- [ ] `spine.context` returns governance brief + live state
- [ ] Session hook uses spine.context (not static embed)
- [ ] D65-v2 passes (shim presence, not embed parity)
- [ ] AGENTS.md + CLAUDE.md under 50 lines each

### WS-5 Gate: Sync Artifacts Retired
- [ ] sync-agent-surfaces.sh archived
- [ ] sync-slash-commands.sh archived
- [ ] .mcp.json removed
- [ ] All gates pass without retired artifacts
