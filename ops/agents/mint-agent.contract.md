# mint-agent Contract

> **Status:** registered
> **Domain:** mint-modules
> **Owner:** @ronny
> **Created:** 2026-02-12
> **Loop:** CP-20260212T105000Z (mint-agent-mcp-tooling)

---

## Identity

- **Agent ID:** mint-agent
- **Domain:** mint-modules (artwork, quote-page, order-intake)
- **Implementation:** `~/code/mint-modules/agents/mcp-server/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | Services | VMs |
|---------|----------|-----|
| Seed intake queries | files-api (artwork) | VM 213 (mint-apps) |
| Upload/asset tracking | files-api (artwork) | VM 213 (mint-apps) |
| Job lifecycle queries | files-api (artwork) | VM 213 (mint-apps) |
| Contract validation | order-intake | VM 213 (mint-apps) |
| Module health monitoring | files-api, order-intake, quote-page | VM 213 (mint-apps) |
| Finance event mapping | finance-adapter | VM 213 (mint-apps) |
| Data plane health | PostgreSQL, MinIO, Redis | VM 212 (mint-data) |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Compose deployment | `ops/bindings/docker.compose.targets.yaml` (mint-apps, mint-data) |
| Health probes (up/down) | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `/spine/services/artwork/`, `/spine/services/quote-page/`, `/spine/services/order-intake/` |
| SSH targets | `ops/bindings/ssh.targets.yaml` (mint-apps, mint-data) |
| Spine capabilities | `ops/plugins/mint/` (5 capabilities) |

## Invocation

On-demand via Claude Code/Desktop MCP. No watchers, no cron.

## Endpoints

| VM | Tailscale IP | Role |
|----|-------------|------|
| 213 (mint-apps) | 100.79.183.14 | App plane: files-api (:3500), order-intake (:3400), quote-page (:3341) |
| 212 (mint-data) | 100.106.72.25 | Data plane: PostgreSQL (:5432), MinIO (:9000), Redis (:6379) |

## V1 Tools (Read-Only)

| Tool | Safety | Description |
|------|--------|-------------|
| `query_seeds` | read-only | Query artwork seeds with status/needs_line_item filters |
| `list_uploads` | read-only | List recent seeds with associated file assets |
| `query_artwork_jobs` | read-only | Look up job by number or UUID |
| `validate_intake` | read-only | Validate customer contract payload (no creation) |
| `check_module_health` | read-only | Health probe for all endpoints |

## Mutation Policy

No mutation tools in V1. Future mutations require:
1. API key auth via Infisical injection
2. Spine capability registration
3. D66 MCP parity gate compliance
