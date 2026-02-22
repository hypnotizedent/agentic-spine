---
status: authoritative
owner: "@ronny"
generated_at: 2026-02-17
scope: aof-v1.1-surface-unification-reconciliation
parent_gap: GAP-OP-627
parent_loop: LOOP-AOF-V1-1-SURFACE-UNIFICATION-20260217
---

# AOF v1.1 Surface Unification — Reconciliation Audit

> Reconciliation of design proposal against current main state.
> Source: `docs/product/AOF_V1_1_SURFACE_UNIFICATION.md`

## Design vs Implementation Parity

### WS-1: Design Doc

| Item | Status | Evidence |
|------|--------|----------|
| Design doc committed | DONE | `docs/product/AOF_V1_1_SURFACE_UNIFICATION.md` on main |
| GAP-OP-627 filed | DONE | `ops/bindings/operational.gaps.yaml` entry with parent_loop |
| Loop scope created | DONE | `mailroom/state/loop-scopes/LOOP-AOF-V1-1-SURFACE-UNIFICATION-20260217.scope.md` |
| Problem statement documented | DONE | 5-row sync sprawl matrix in design doc |
| Three-move architecture specified | DONE | Moves 1/2/3 with acceptance criteria |
| Sequencing defined | DONE | Move 1 → Move 2 → Move 3, each independently shippable |
| Impact analysis complete | DONE | Files created/modified/retired tables |
| Risk assessment complete | DONE | 4-row risk/mitigation table |

**WS-1 verdict: COMPLETE**

### WS-2: Move 1 — Unified Spine-MCP Gateway

| Item | Status | Evidence |
|------|--------|----------|
| `ops/plugins/mcp-gateway/bin/spine-mcp-serve` | NOT STARTED | Directory does not exist |
| `./bin/ops mcp serve` CLI subcommand | NOT STARTED | No mcp routing in `bin/ops` |
| `spine.mcp.serve` capability registered | NOT STARTED | Not in `ops/capabilities.yaml` |
| RAG MCP absorbed into gateway | NOT STARTED | `rag-mcp-server` still standalone |
| Single-line surface config documented | NOT STARTED | |

**WS-2 verdict: DEFERRED — implementation scope, requires own loop**

### WS-3: Move 2 — Queryable Agent Registry

| Item | Status | Evidence |
|------|--------|----------|
| `agent.route` capability | DONE | `ops/capabilities.yaml:4168`, `ops/plugins/agent/bin/agent-route` |
| `agent.route --list` subcommand | DONE | Implemented in agent-route script |
| `agents.registry.yaml` routing rules | DONE | 8 agents with domains + keywords |
| `mcp_tools` field in registry | NOT STARTED | No `mcp_tools:` entries in registry |
| `write_scope` field in registry | NOT STARTED | No `write_scope:` entries in registry |
| `capabilities` field in registry | NOT STARTED | No per-agent cap lists in registry |
| `endpoints` field in registry | NOT STARTED | No `endpoints:` entries in registry |
| `agent.info` capability | NOT STARTED | Not in capabilities.yaml |
| `agent.tools` capability | NOT STARTED | Not in capabilities.yaml |

**WS-3 verdict: PARTIAL — routing exists, schema extension + info/tools caps deferred**

### WS-4: Move 3 — Dynamic Context Delivery

| Item | Status | Evidence |
|------|--------|----------|
| `spine.context` capability | NOT STARTED | Not in capabilities.yaml |
| `ops/plugins/context/bin/spine-context` | NOT STARTED | Directory does not exist |
| D65-v2 gate script | NOT STARTED | D65 still enforces embed parity |
| AGENTS.md thin shim conversion | NOT STARTED | Full governance embed still present |
| CLAUDE.md thin shim conversion | NOT STARTED | Full governance embed still present |
| `sync-agent-surfaces.sh` retirement | NOT STARTED | Script still active in ops/hooks/ |
| `sync-slash-commands.sh` retirement | NOT STARTED | Script still active in ops/hooks/ |

**WS-4 verdict: NOT STARTED — depends on Move 1 gateway**

### WS-5: Retire Sync Artifacts

| Item | Status | Evidence |
|------|--------|----------|
| `sync-agent-surfaces.sh` retired | NOT STARTED | Still active |
| `sync-slash-commands.sh` retired | NOT STARTED | Still active |
| `.mcp.json` absorbed | NOT STARTED | Still active at spine root |
| MCPJungle config-only JSONs | NOT STARTED | Still in workbench |

**WS-5 verdict: NOT STARTED — depends on Moves 1+3**

## Remaining Deltas to Close GAP-OP-627

GAP-OP-627 scope: *"Surface sync sprawl ... AOF v1.0 lacks dynamic context delivery and a unified MCP gateway."*

The gap registered the architectural problem. The design doc provides the resolution contract. The gap is closable when the problem has a committed, approved architectural path — the design proposal fulfills this.

**Implementation of Moves 1-3 is out-of-scope for GAP-OP-627.** Each move should spawn its own child loop:
- `LOOP-SPINE-MCP-GATEWAY-V1-YYYYMMDD` (Move 1)
- `LOOP-AGENT-REGISTRY-SCHEMA-V2-YYYYMMDD` (Move 2)
- `LOOP-DYNAMIC-CONTEXT-DELIVERY-YYYYMMDD` (Move 3)

## File Touch List (This Closure)

| File | Action | Reason |
|------|--------|--------|
| `docs/product/AOF_V1_1_SURFACE_UNIFICATION.md` | modify | Promote status: draft → approved |
| `docs/governance/_audits/AOF_V1_1_SURFACE_UNIFICATION_RECON_20260217.md` | create | This reconciliation audit |
| `docs/governance/_audits/AOF_V1_1_SURFACE_UNIFICATION_CERT_20260217.md` | create | Closeout certification |
| `ops/bindings/operational.gaps.yaml` | modify | GAP-OP-627 status: open → fixed |
| `mailroom/state/loop-scopes/LOOP-AOF-V1-1-SURFACE-UNIFICATION-20260217.scope.md` | modify | status: active → closed |

## Preflight Run Keys

| Capability | Run Key | Result |
|-----------|---------|--------|
| stability.control.snapshot | `CAP-20260217-152737__stability.control.snapshot__Rpiut40603` | WARN (non-blocking) |
| verify.core.run | `CAP-20260217-152802__verify.core.run__R6rvd43515` | 8/8 PASS |
| verify.domain.run aof | `CAP-20260217-152846__verify.domain.run__Rbd4x64656` | 19/19 PASS |
| proposals.status | `CAP-20260217-152859__proposals.status__R1lg573523` | 8 pending, 0 breaches |
| gaps.status | `CAP-20260217-152901__gaps.status__R4idk74311` | 3 open (590, 627, 635) |
