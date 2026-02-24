# finance-agent Contract

> **Status:** active
> **Domain:** finance-ops
> **Owner:** @ronny
> **Created:** 2026-02-12
> **Supersedes:** firefly-agent, paperless-agent

---

## Identity

- **Agent ID:** finance-agent
- **Domain:** finance-ops (unified personal finance + document management)
- **Implementation:** `~/code/workbench/agents/finance/` (V1 TypeScript MCP server)
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

V1.1 implements a TypeScript MCP server (`workbench/agents/finance/tools/`) with 21 tools:

### Firefly III (8 tools)

| Tool | Description |
|------|-------------|
| `finance_status` | Health-check all finance services on VM 211 (Firefly III, Paperless-ngx) |
| `list_accounts` | List Firefly III accounts with balances, filterable by type (asset, expense, revenue, liability) |
| `get_account_detail` | Get detailed account info by ID (balance, currency, IBAN, notes) |
| `list_transactions` | List transactions within a date range, filterable by type (withdrawal, deposit, transfer) |
| `search_transactions` | Search transactions by keyword across description, notes, and text fields |
| `list_categories` | List transaction categories with current-month spending totals |
| `list_budgets` | List budgets with period amounts and spending progress |
| `list_bills` | List recurring bills with amounts, frequency, and next expected date |

### Paperless-ngx (5 tools)

| Tool | Description |
|------|-------------|
| `search_documents` | Full-text search across Paperless-ngx documents |
| `list_documents` | List documents with pagination and sort options |
| `get_document_detail` | Get document metadata, tags, correspondent, and extracted text content |
| `list_tags` | List all document tags with document counts |
| `list_correspondents` | List all correspondents (document sources/senders) with document counts |

### Ghostfolio (3 tools)

| Tool | Description |
|------|-------------|
| `ghostfolio_holdings` | List investment holdings with current values and allocation |
| `ghostfolio_accounts` | List Ghostfolio investment accounts with balances |
| `ghostfolio_activities` | List investment activities (buy, sell, dividend) |

### Tax & Compliance (2 tools)

| Tool | Description |
|------|-------------|
| `tax_1099_summary` | Contractor payment aggregation for 1099 prep |
| `sales_tax_dr15` | FL sales tax calculation from Mint OS + Firefly |

### Agent Pipeline (3 tools)

| Tool | Description |
|------|-------------|
| `finance_transaction_pipeline_status` | Transaction import pipeline health and sync status |
| `finance_ronny_action_queue` | Pending manual actions requiring owner review |
| `finance_filing_packet` | Generate filing packet for tax/compliance deadlines |

Superseded config-only MCP servers (`firefly.json`, `paperless.json`) are deactivated (enabled: false) in MCPJungle.

## Deployment

MCP server is live. SimpleFIN daily sync active (cron `0 6 * * *` on VM 211).

```bash
# Build (after changes)
cd ~/code/workbench/agents/finance/tools
npm install && npm run build

# Secrets (Infisical infrastructure/prod)
# FIREFLY_ACCESS_TOKEN, PAPERLESS_API_TOKEN, GHOSTFOLIO_ACCESS_TOKEN
# FIREFLY_URL=http://100.76.153.100:8080
# PAPERLESS_URL=http://100.76.153.100:8000
# GHOSTFOLIO_URL=http://100.76.153.100:3333
```

## Invocation

On-demand via Claude Code session. No watchers, no cron (WORKBENCH_CONTRACT compliance).

V2 roadmap includes scheduled mailroom prompts for health digest and tax calendar.

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

## V2 Roadmap

| Tool | Description | Status |
|------|-------------|--------|
| `reconciliation_report` | Cross-service transaction reconciliation | Planned |
| `financial_health_digest` | Cross-service financial health summary | Planned |
| `receipt_link` | Link Paperless receipt to Firefly transaction (write-gated) | Planned |
| `transaction_categorize` | Bulk categorize transactions (write-gated) | Planned |
