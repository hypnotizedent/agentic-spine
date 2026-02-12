# finance-agent Contract

> **Status:** registered
> **Domain:** finance-ops
> **Owner:** @ronny
> **Created:** 2026-02-12
> **Supersedes:** firefly-agent, paperless-agent

---

## Identity

- **Agent ID:** finance-agent
- **Domain:** finance-ops (unified personal finance + document management)
- **Implementation:** `~/code/workbench/agents/finance/` (pending — V1 registration only)
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Transaction queries, categorization, reconciliation | Firefly III API |
| Account/budget views and balance monitoring | Firefly III API |
| Document search, receipt management, W-9 retrieval | Paperless-ngx API |
| Investment tracking (when configured) | Ghostfolio API |
| Contractor payment aggregation (1099 prep) | Firefly III API |
| FL sales tax calculation (DR-15 prep) | Mint OS revenue + Firefly III |
| Tax calendar and compliance deadline tracking | Agent config |
| Receipt-to-transaction linking | Paperless-ngx + Firefly III |
| Financial health digest (cross-service read) | All finance services |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Stack deployment | `ops/bindings/docker.compose.targets.yaml` (finance-stack) |
| Health probes | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `/spine/services/finance/`, `/spine/services/paperless/` |
| Domain routing | `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` |
| Backup | `ops/bindings/backup.inventory.yaml` |
| SSH targets | `ops/bindings/ssh.targets.yaml` |
| Operational runbooks | `docs/pillars/finance/` |

If a finance-agent finding requires an infrastructure change, file it to the spine mailroom:
`cd ~/code/agentic-spine && ./bin/ops run --inline "finance-agent finding: <what> (evidence + proposed change)"`

## Governed Tools

No custom tools in V1 (registration only). V2 will implement a TypeScript MCP server following the media-agent pattern.

Existing config-only MCP servers (`firefly.json`, `paperless.json`) remain active in MCPJungle until V2 consolidation.

## Endpoints

| Service | Host | Port | Notes |
|---------|------|------|-------|
| Firefly III | VM 211 (finance-stack) | 8080 | Personal finance |
| Paperless-ngx | VM 211 (finance-stack) | 8000 | Document management |
| Ghostfolio | VM 211 (finance-stack) | 3333 | Investment tracking |
| Mail Archiver | VM 211 (finance-stack) | 5100 | Email receipt capture |
| PostgreSQL | VM 211 (finance-stack) | 5434 | Internal only |
| Redis | VM 211 (finance-stack) | 6381 | Internal only |

**Tailscale:** 100.76.153.100
**LAN:** 192.168.1.211

## Integration Points

| Integration | Description |
|-------------|-------------|
| finance-adapter | Mint billable event bridge (mint-modules repo) |
| SimpleFIN | Daily bank sync (cron on VM 211) |
| n8n (VM 202) | Firefly-to-Mint OS expense webhook |

## Invocation

On-demand via Claude Code session. No watchers, no cron (WORKBENCH_CONTRACT compliance).

V2 roadmap includes scheduled mailroom prompts for health digest and tax calendar.
