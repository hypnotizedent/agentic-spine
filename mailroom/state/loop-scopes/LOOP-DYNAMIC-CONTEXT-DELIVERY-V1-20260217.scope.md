---
loop_id: LOOP-DYNAMIC-CONTEXT-DELIVERY-V1-20260217
status: closed
closed_at: 2026-02-17
owner: "@ronny"
priority: medium
created: 2026-02-17
parent_loop: LOOP-AOF-V1-1-SURFACE-ROLLDOWN-20260217
design_ref: docs/product/AOF_V1_1_SURFACE_UNIFICATION.md#move-3
---

# Move 3 — Dynamic Context Delivery

## Objective

Replace static governance brief embeds with a `spine.context` capability that serves the
current brief + live state on demand. Evolve D65 from embed-parity to shim-presence check.

## Deliverables

- [x] `ops/plugins/context/bin/spine-context` — context delivery capability script
- [x] `spine.context` capability registered
- [x] `session-entry-hook.sh` refactored to call spine.context
- [ ] AGENTS.md converted to thin shim — DEFERRED (D65 preserved per constraint)
- [ ] CLAUDE.md converted to thin shim — DEFERRED (D65 preserved per constraint)
- [ ] OPENCODE.md (workbench) converted to thin shim — DEFERRED (D65 preserved per constraint)
- [ ] D65-v2 gate script — DEFERRED (D65 full-embed preserved per constraint)
- [ ] D65 gate entry updated — DEFERRED (D65 full-embed preserved per constraint)

## Closure Note

Core capability (spine.context) and session-entry-hook integration complete.
Thin shim conversion and D65-v2 evolution deferred — blocked by D65 full-embed
preservation constraint. Remaining items tracked under GAP-OP-639 (sync artifact retirement)
which itself is blocked until GAP-OP-636 (MCP gateway / Move 1) is also complete.

## Target Files

| File | Action |
|------|--------|
| `ops/plugins/context/bin/spine-context` | create |
| `ops/capabilities.yaml` | modify (register spine.context) |
| `ops/bindings/capability_map.yaml` | modify (add navigation entry) |
| `ops/hooks/session-entry-hook.sh` | modify (call spine.context) |
| `AGENTS.md` | modify (thin shim) |
| `CLAUDE.md` | modify (thin shim) |
| `surfaces/verify/d65-agent-briefing-sync-lock.sh` | modify (evolve to v2) |
| `ops/bindings/gate.registry.yaml` | modify (update D65 description) |

## Acceptance Criteria

1. `./bin/ops cap run spine.context` returns governance brief + live state YAML
2. Session entry hook injects context dynamically
3. D65-v2 gate passes (shim presence check)
4. All Core-8 + AOF domain gates pass
5. AGENTS.md and CLAUDE.md are under 50 lines each (thin shims)

## Constraints

- AGENT_GOVERNANCE_BRIEF.md remains single source file
- Staged rollout: keep embeds until verification, then cut over
- Must coordinate with Claude Desktop skill update
