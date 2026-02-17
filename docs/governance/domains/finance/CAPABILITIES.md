---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: domain-capability-catalog
domain: finance
---

# finance Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `finance.stack.status` | `read-only` | `auto` | `agents/finance/` |

## MCP Server (workbench)

The finance-agent MCP server (`~/code/workbench/agents/finance/tools/`) provides 13 read-only tools
that are invoked directly by Claude Desktop, not through the spine capability runner.

| Tool | Service | Description |
|------|---------|-------------|
| `finance_status` | Firefly + Paperless | Health-check all finance services |
| `list_accounts` | Firefly III | Account listing with balances |
| `get_account_detail` | Firefly III | Account detail by ID |
| `list_transactions` | Firefly III | Transactions by date range |
| `search_transactions` | Firefly III | Keyword search across transactions |
| `list_categories` | Firefly III | Categories with spending totals |
| `list_budgets` | Firefly III | Budgets with progress |
| `list_bills` | Firefly III | Recurring bills with schedules |
| `search_documents` | Paperless-ngx | Full-text document search |
| `list_documents` | Paperless-ngx | Paginated document listing |
| `get_document_detail` | Paperless-ngx | Document metadata + extracted text |
| `list_tags` | Paperless-ngx | Tags with document counts |
| `list_correspondents` | Paperless-ngx | Correspondents with document counts |

### Deployment Status

- **Source:** Complete (13 tools in `agents/finance/tools/src/index.ts`)
- **Build:** Requires `npm install && npm run build` in workbench
- **Secrets:** `FIREFLY_PAT`, `PAPERLESS_API_TOKEN` from Infisical `infrastructure/prod`
- **Registration:** Add `finance-agent` entry to Claude Desktop config
- **VM 211 reachability:** Required (Tailscale `100.76.153.100` or LAN `192.168.1.211`)

### Canonical Secret Rotation

```bash
# Read-only verification (project/path/auth)
./bin/ops cap run secrets.bundle.verify finance

# Apply new tokens from clipboard JSON (no web UI path hunting)
echo "yes" | ./bin/ops cap run secrets.bundle.apply finance --clipboard --sync-local-env
```
