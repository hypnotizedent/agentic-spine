---
loop_id: LOOP-AOF-V1-1-SURFACE-UNIFICATION-20260217
status: active
owner: "@ronny"
priority: high
created: 2026-02-17
parent_gap: GAP-OP-627
---

# AOF v1.1 — Surface Unification

## Objective

Eliminate surface sync sprawl by introducing three architectural changes that reduce the per-surface maintenance burden from N manual touch-points to zero for governance updates and new agent onboarding.

## Problem Statement

AOF v1.0 surfaces were bolted on incrementally. The governance brief is statically embedded in 3 files via sync hooks. MCP servers are configured independently in 4 locations. Agent contracts are prose-only markdown that no machine can query. Slash commands are synced by shell script to 3 targets. Every update propagates through a manual chain that creates drift risk and onboarding friction.

## Workstreams

- [ ] WS-1: Design doc — `docs/product/AOF_V1_1_SURFACE_UNIFICATION.md`
- [ ] WS-2: Move 1 — Unified spine-mcp gateway (`ops/plugins/mcp-gateway/`)
- [ ] WS-3: Move 2 — Queryable agent registry schema (`ops/bindings/agents.registry.yaml`)
- [ ] WS-4: Move 3 — `spine.context` capability + D65-v2 gate evolution
- [ ] WS-5: Retire sync artifacts — `sync-agent-surfaces.sh`, `sync-slash-commands.sh`, per-surface MCP configs

## Sequencing

WS-1 (design) must complete before any implementation.
WS-2 (gateway) first — highest leverage, most surface debt removed.
WS-3 (registry) second — small schema evolution, immediate queryability.
WS-4 (context) last — requires D65-v2 gate refactor.
Each workstream is independently shippable.

## Exit Criteria

- Single MCP server config line works in Claude Code, Claude Desktop, and OpenCode
- `./bin/ops agent info <name>` returns machine-queryable contract data
- Governance brief updates propagate without running sync scripts
- Net reduction in files maintained per new agent onboard
- Zero new drift gates required (existing gates evolve)

## Constraints

- AOF v1.0 policy runtime (presets, 10 knobs) unchanged
- `./bin/ops cap run` interface unchanged
- Backward-compatible: existing caps continue to work throughout migration
- No breaking changes to receipt format or verify lanes
