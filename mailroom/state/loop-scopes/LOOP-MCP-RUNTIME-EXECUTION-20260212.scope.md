---
status: active
owner: "@ronny"
created: 2026-02-12
scope: loop-scope
loop_id: LOOP-MCP-RUNTIME-EXECUTION-20260212
severity: high
---

# Loop Scope: LOOP-MCP-RUNTIME-EXECUTION-20260212

## Goal

Execute MCP runtime hardening end-to-end (not audits): eliminate remaining
mutating bypass paths, enforce governed tool behavior, and leave one clear
runtime contract for agents.

## Success Criteria

1. Mutating MCP tools are either governed/blocked or mapped to a controlled capability path.
2. No inline secrets remain in MCP server/runtime configs.
3. Local and MCPJungle copies are parity-checked or explicitly divergence-documented.
4. `spine.verify` passes at closeout.

## Phases

### P0: Baseline
- [ ] Capture current MCP tool surface and mutating-tool inventory.
- [ ] Capture current bypass/blocked matrix with evidence.

### P1: Enforcement
- [ ] Implement/verify governed blocking on all mutating MCP paths still exposed.
- [ ] Normalize any config-level bypasses that circumvent spine governance.

### P2: Secret + Parity
- [ ] Remove/replace any inline credentials in MCP configs.
- [ ] Reconcile local vs MCPJungle drift or record explicit allowed divergence.

### P3: Closeout
- [ ] Re-run core validation (`spine.verify`, runtime checks).
- [ ] Update loop evidence and close.

## Notes

This loop is intentionally execution-first. No standalone report phase.
