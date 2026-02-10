---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-MAILROOM-MCP-BRIDGE-20260210
---

# Loop Scope: LOOP-MAILROOM-MCP-BRIDGE-20260210

## Goal
Provide a governed remote interface (MCP/API) to the spine mailroom so an iPhone
client can read receipts/outbox, enqueue prompts, and inspect open loops without
SSH or repo spelunking.

## Success Criteria
- A minimal server/tooling surface exists for: enqueue prompt, list open loops,
  read outbox result, read receipt.
- Auth is explicit and non-leaky (Tailscale ACL, token, or both).
- Lifecycle is governed (start/stop/status capability + receipts).
- Documented integration path for n8n workflows.

## Phases
- P0: Inventory existing MCPJungle/AnythingLLM/Qdrant endpoints + gaps
- P1: Implement mailroom bridge (MCP or HTTP API) with strict allowlist
- P2: Add n8n workflow triggers (read/write)
- P3: Closeout + SSOT updates

## Evidence (Receipts)
- (link receipts here)

