# mint-os-agent Contract

> **Status:** registered
> **Domain:** commerce
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** mint-os-agent
- **Domain:** commerce (MintPrints e-commerce operations)
- **MCP Server:** `~/code/workbench/infra/compose/mcpjungle/servers/mint-os/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Order email dispatch | MintOS API |
| Production status updates | MintOS API |
| Customer data updates | MintOS API |
| SanMar/S&S order placement | Supplier APIs |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Stack deployment | `ops/bindings/docker.compose.targets.yaml` |
| Health probes | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `/spine/vm-infra/mint-os/` |

## Governed Tools

| Tool | Status | Spine Capability |
|------|--------|-----------------|
| send_order_email | BLOCKED (P2) | None — deferred (mint-os out of scope) |
| post_production_update | BLOCKED (P2) | None — deferred |
| update_order_customer | BLOCKED (P2) | None — deferred |
| ss_place_order | BLOCKED (P2) | None — deferred |
| sanmar_place_order | BLOCKED (P2) | None — deferred |

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| MintOS API | docker-host (VM 200) | Legacy stack — deferred from spine governance |
