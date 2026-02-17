---
loop_id: LOOP-AOF-V1-1-SURFACE-ROLLDOWN-20260217
status: active
owner: "@ronny"
priority: high
created: 2026-02-17
parent_design: docs/product/AOF_V1_1_SURFACE_UNIFICATION.md
predecessor_loop: LOOP-AOF-V1-1-SURFACE-UNIFICATION-20260217
---

# AOF v1.1 — Surface Unification Rolldown

## Objective

Convert the approved AOF v1.1 design (`docs/product/AOF_V1_1_SURFACE_UNIFICATION.md`) into
a vertically integrated execution runway with child loops, gaps, and dependency mapping so
agents can discover and execute workstreams without relying on memory or manual lists.

## Scope

Registration and planning only. No implementation code changes in plugins or capabilities
runtime. This loop produces:
1. Four child loop scopes (one per implementation workstream)
2. Four gap registrations (one per workstream)
3. A vertical integration artifact mapping WS -> GAP -> LOOP -> files -> compliance
4. A master change proposal packaging the registration artifacts

## Child Loops

| Child Loop | Workstream | Design Move |
|-----------|------------|-------------|
| LOOP-SPINE-MCP-GATEWAY-V1-20260217 | WS-2 | Move 1: Unified MCP gateway |
| LOOP-AGENT-REGISTRY-SCHEMA-V2-20260217 | WS-3 | Move 2: Queryable agent registry |
| LOOP-DYNAMIC-CONTEXT-DELIVERY-V1-20260217 | WS-4 | Move 3: Dynamic context |
| LOOP-SYNC-ARTIFACT-RETIREMENT-V1-20260217 | WS-5 | Retire sync scripts |

## Sequencing

WS-2 (gateway) first, WS-3 (registry) second, WS-4 (context) third, WS-5 (retire) last.
WS-5 depends on WS-4 completion. All others are independently shippable.

## Exit Criteria

- All four child loop scopes committed
- All four gaps filed with parent_loop linkage
- Vertical integration artifact published to docs/governance/_audits/
- Master CP submitted (pending, not applied)
- All drift gates pass
