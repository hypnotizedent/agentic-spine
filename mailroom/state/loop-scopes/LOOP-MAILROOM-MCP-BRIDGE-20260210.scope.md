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
- Capabilities (receipted):
  - `mailroom.bridge.status` (PID + /health)
  - `mailroom.bridge.start` (daemon start)
  - `mailroom.bridge.stop` (daemon stop)
  - Proof runs:
    - `receipts/sessions/RCAP-20260210-100458__mailroom.bridge.start__Ryjn618007/receipt.md`
    - `receipts/sessions/RCAP-20260210-100458__mailroom.bridge.status__Rf2w518066/receipt.md` (running)
    - `receipts/sessions/RCAP-20260210-100458__mailroom.bridge.stop__Ry36418109/receipt.md`
    - `receipts/sessions/RCAP-20260210-100458__mailroom.bridge.status__R7u1317994/receipt.md` (stopped)
- Code:
  - `ops/bindings/mailroom.bridge.yaml`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-start`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-stop`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-status`
- Docs:
  - `docs/governance/MAILROOM_BRIDGE.md`
