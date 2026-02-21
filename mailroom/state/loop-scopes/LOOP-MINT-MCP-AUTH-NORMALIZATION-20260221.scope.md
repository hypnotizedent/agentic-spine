---
loop_id: LOOP-MINT-MCP-AUTH-NORMALIZATION-20260221
created: 2026-02-21
status: closed
owner: "@ronny"
scope: mint
priority: medium
objective: Fix 401s for mint MCP tools by wiring secrets-exec and adding fallback key chain
---

# Loop Scope: LOOP-MINT-MCP-AUTH-NORMALIZATION-20260221

## Objective

Fix 401s for mint MCP tools by wiring secrets-exec and adding fallback key chain

## Resolution

Partial complete. pricing_estimate and suppliers_sync_status fixed (GAP-OP-801 closed).
finance_reconcile_latest blocked on FINANCE_ADAPTER_API_KEY missing in Infisical (GAP-OP-802 open).

## Changes
- `mint-modules/agents/mcp-server/src/index.ts`: added canonical env var fallback chain
- `agentic-spine/.mcp.json`: wrapped mint MCP servers with secrets-exec
- Commits: mint-modules@3e4dfc5, agentic-spine@0f6a89f

## Residual Blockers
- GAP-OP-802: FINANCE_ADAPTER_API_KEY must be provisioned in Infisical (infrastructure/prod path)
