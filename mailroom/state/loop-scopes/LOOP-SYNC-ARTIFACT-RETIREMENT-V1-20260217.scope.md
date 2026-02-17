---
loop_id: LOOP-SYNC-ARTIFACT-RETIREMENT-V1-20260217
status: closed
owner: "@ronny"
priority: medium
created: 2026-02-17
parent_loop: LOOP-AOF-V1-1-SURFACE-ROLLDOWN-20260217
depends_on: LOOP-DYNAMIC-CONTEXT-DELIVERY-V1-20260217
design_ref: docs/product/AOF_V1_1_SURFACE_UNIFICATION.md#ws-5
---

# WS-5 — Sync Artifact Retirement

## Objective

Retire the sync scripts and per-surface MCP configs that become redundant after Moves 1-3
are complete.

## Deliverables

- [ ] Archive `ops/hooks/sync-agent-surfaces.sh` (replaced by dynamic context)
- [ ] Archive `ops/hooks/sync-slash-commands.sh` (commands served via MCP gateway)
- [ ] Remove `.mcp.json` from spine root (absorbed by gateway)
- [ ] Document MCPJungle config-only JSON retirement path (workbench scope)
- [ ] Update any gates referencing retired artifacts
- [ ] Verify net file count delta is negative

## Target Files

| File | Action |
|------|--------|
| `ops/hooks/sync-agent-surfaces.sh` | archive (move to .archive/) |
| `ops/hooks/sync-slash-commands.sh` | archive (move to .archive/) |
| `.mcp.json` | delete |
| Gate scripts referencing sync hooks | modify (remove references) |

## Acceptance Criteria

1. `sync-agent-surfaces.sh` no longer in ops/hooks/ (archived)
2. `sync-slash-commands.sh` no longer in ops/hooks/ (archived)
3. `.mcp.json` removed from spine root
4. All gates pass without the retired artifacts
5. Governance brief updates propagate without running any sync script

## Constraints

- Depends on Move 3 (dynamic context) being complete and verified
- MCPJungle retirement is workbench-scoped (out of spine repo scope)
- D48 worktree hygiene must pass after archival
