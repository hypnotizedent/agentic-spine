# ms-graph-agent Contract

> **Status:** planned
> **Domain:** identity
> **Owner:** @ronny
> **Created:** 2026-03-01
> **Loop:** LOOP-SPINE-SHAREABILITY-HARDENING-20260301

---

## Identity

- **Agent ID:** `ms-graph-agent`
- **Domain:** `identity` (Microsoft Graph helper surface)
- **Workbench Implementation Root:** `~/code/workbench/agents/ms-graph/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Scope

This contract declares visibility and ownership for the `workbench/agents/ms-graph`
surface so agent discovery no longer omits it.

Current state is **planned** integration:

- discovery and routing are registered in spine
- operational capabilities are intentionally not promoted yet
- runtime/tool parity checks remain scoped to `microsoft-agent` until promotion

## Promotion Criteria

Before moving to `implementation_status: active`:

1. Define governed capability mapping for each exposed Graph operation.
2. Add runtime binding parity proof (D148) for the active MCP endpoint.
3. Add project attach binding and verify pack ownership.
4. Publish a migration receipt linking ms-graph tools to canonical identity routing.
