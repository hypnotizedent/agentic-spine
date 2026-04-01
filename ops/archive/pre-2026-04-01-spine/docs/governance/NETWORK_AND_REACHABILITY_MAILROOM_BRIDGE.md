---
status: superseded_historical
owner: "@ronny"
last_verified: 2026-03-26
scope: network-and-reachability-mailroom-bridge
product_family: NetworkAndReachability
---

# Network And Reachability - Mailroom Bridge

This is the surviving authority surface for the mailroom bridge under the spine `NetworkAndReachability` product family.

## Authority Boundary

- `ops/bindings/mailroom.bridge.consumers.yaml` is the SSOT for Cap-RPC allowlist and role/token routing.
- `ops/bindings/mailroom.bridge.yaml` is the live bridge binding.
- This doc defines the operator-facing bridge contract and carries the generated consumer table.

## Bridge Surface

- `/health` proves bridge reachability.
- `/cap/run` exposes governed bridge capability execution; bridge consumers do not invent their own mutation or authority rules.
- `/rag/ask` exposes the governed bridge RAG surface.

## Response contract

- `/rag/ask` supports `auto|chat|retrieve`.
- The response payload must include a `mode` field that reports the actual mode used.
- Source normalization strips hotdir path artifacts before sources are returned.
- `document_metadata` tags must be stripped from answer text before bridge responses are returned.
- Retrieve-mode sources should render as clean filenames or repo-relative references, not storage or hotdir internals.
- `/cap/run` remains governed and receipt-backed through the underlying capability contract.

## Bridge Consumers

<!-- AUTO: BRIDGE_CONSUMERS_START -->
Bridge Cap-RPC consumers (SSOT: `ops/bindings/mailroom.bridge.consumers.yaml`):

| Role | Token Env | Cap-RPC access |
|------|-----------|----------------|
| `operator` | `MAILROOM_BRIDGE_TOKEN` | \`*\` (full allowlist) |
| `monitor` | `MAILROOM_BRIDGE_MONITOR_TOKEN` | `spine.verify`, `surface.mobile.dashboard.status`, `gaps.status`, `loops.status`, `proposals.status`, `mailroom.bridge.status`, `aof.status`, `aof.version`, `spine.broker.get_latest_loop`, `spine.broker.get_loop_status`, `spine.broker.get_loop_progress`, `spine.broker.get_request_attestation`, `loops.list`, `loops.progress`, `gaps.aging`, `receipts.summary`, `receipts.search`, `receipts.trends`, `proposals.list`, `cloudflare.status`, `cloudflare.zone.list`, `cloudflare.token.health` |
| `media-consumer` | `MAILROOM_BRIDGE_MEDIA_TOKEN` | `media.health.check`, `media.service.status`, `media.nfs.verify` |
| `task-automation` | `MAILROOM_BRIDGE_TASK_TOKEN` | `mailroom.task.enqueue`, `mailroom.task.claim`, `mailroom.task.heartbeat`, `mailroom.task.complete`, `mailroom.task.fail` |
| `mint-voice` | `MAILROOM_BRIDGE_N8N_MORPHEUS_VOICE_TOKEN` | `mint.customer.voice.intake.capture`, `mint.customer.voice.callback.enqueue`, `mint.customer.frontdesk.facts.get` |

Update path:
- `bash ops/plugins/infra/mailroom-bridge/bin/mailroom-bridge-consumers-sync`
<!-- AUTO: BRIDGE_CONSUMERS_END -->
