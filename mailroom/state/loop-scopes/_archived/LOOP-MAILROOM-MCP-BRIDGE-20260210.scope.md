---
status: closed
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
  - `mailroom.bridge.expose.enable` (tailnet-only exposure via Tailscale Serve)
  - `mailroom.bridge.expose.status` (tailnet URL + health)
  - `spine.status` (watcher + queue status)
  - Proof runs:
    - `receipts/sessions/RCAP-20260210-122349__mailroom.bridge.start__Rf2yb17960/receipt.md` (launchd start + /health)
    - `receipts/sessions/RCAP-20260210-122340__mailroom.bridge.stop__R5ogk17619/receipt.md` (launchd stop)
    - `receipts/sessions/RCAP-20260210-121309__mailroom.bridge.status__R8sbo3067/receipt.md` (running + /health)
    - `receipts/sessions/RCAP-20260210-122252__mailroom.bridge.expose.status__Ryi3f16795/receipt.md` (tailnet_url + health OK)
    - `receipts/sessions/RCAP-20260210-122247__mailroom.bridge.expose.enable__R6sxk16635/receipt.md` (HTTP:80 enable)
    - `receipts/sessions/RCAP-20260210-122925__spine.status__R3tu021395/receipt.md` (watcher running)
- Code:
  - `ops/bindings/mailroom.bridge.yaml`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-start`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-stop`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-status`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-expose-enable`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-expose-disable`
  - `ops/plugins/mailroom-bridge/bin/mailroom-bridge-expose-status`
  - `fixtures/n8n/Spine_-_Mailroom_Enqueue.json`
- Docs:
  - `docs/governance/MAILROOM_BRIDGE.md`
