---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: workbench-attachment-governance
---

# workbench-agent Contract

## Identity
- Agent ID: `workbench-agent`
- Domain: `workbench`
- Registry Source: `ops/bindings/agents.registry.yaml`
- Implementation Root: `~/code/workbench/agents/workbench/`

## Scope
- Maintain governed project-attach parity for workbench via `.spine-link.yaml` generation.
- Provide read-only diagnostics for workbench implementation and MCP runtime parity.
- Enforce host drift visibility for the local MacBook runtime surface.

## Canonical Capabilities
- `workbench.impl.audit`
- `mcp.runtime.status`
- `host.macbook.drift.check`

## Write Scope
- `~/code/workbench/`

## Governing Gates
- `D49` agent discovery lock
- `D153` project attach parity
