# LOOP-SPINE-VERIFY-RECOVERY-20260215

## Summary
Resolve spine.verify failures (D66, D77) and reconcile SSOT contradictions that confuse agents.

## Status
**CLOSED** — verify PASS (D66+D77 fixed), remaining items deferred to linked gaps

## Scope

### Verify Failures (blocking)
1. **D66 MCP parity drift** — `agents/media/tools/src/index.ts` diverges from MCPJungle copy
2. **D77 Workbench contract drift** — `com.ronny.ha-baseline-refresh.plist` not allowlisted

### SSOT Contradictions (agent-confusing)
3. **Launchd policy split-brain** — `LAUNCHD_RETIREMENT` says "only agent-inbox allowed" but `MACBOOK_SSOT` lists `ha-baseline-refresh` as ACTIVE
4. **RAG query surfaces competing** — `mint ask` deprecated in governance but still implemented and used

### Half-Migrations (lint failures)
5. **Docs frontmatter mismatch** — `OUTPUT_CONTRACTS.md` lacks required YAML frontmatter
6. **Docs structure lint gaps** — `ACTIVE_DOCS_INDEX.md` at wrong location, dirs not allowlisted

### Governance Ambiguity
7. **Workbench baseline conflict** — spine expects `.spine-project.yaml`, workbench has its own `WORKBENCH_CONTRACT.md`

## Out of Scope
- HA-related gaps (GAP-OP-486 through GAP-OP-492) — separate tracking
- Local state risks (dirty workbench, floating stash) — address in closure

## Success Criteria
- `spine.verify` returns PASS
- No SSOT contradictions on launchd policy
- Single canonical RAG query surface
- Docs lint passes

## Linked Gaps
- GAP-OP-493 (D66 MCP parity)
- GAP-OP-494 (D77 Workbench contract)
- GAP-OP-495 (Launchd policy contradiction)
- GAP-OP-496 (RAG surface competition)

## Priority
HIGH — verify gates are FAIL, blocking clean baseline
