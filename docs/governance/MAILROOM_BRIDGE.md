# Mailroom Bridge

Governed reference for the mailroom bridge Cap-RPC consumer surface.

<!-- AUTO: BRIDGE_CONSUMERS_START -->
Bridge Cap-RPC consumers (SSOT: `ops/bindings/mailroom.bridge.consumers.yaml`):

| Role | Token Env | Cap-RPC access |
|------|-----------|----------------|
| `operator` | `MAILROOM_BRIDGE_TOKEN` | \`*\` (full allowlist) |
| `monitor` | `MAILROOM_BRIDGE_MONITOR_TOKEN` | `spine.verify`, `surface.mobile.dashboard.status`, `gaps.status`, `loops.status`, `proposals.status`, `mailroom.bridge.status`, `aof.status`, `aof.version`, `loops.list`, `loops.progress`, `gaps.aging`, `receipts.summary`, `receipts.search`, `receipts.trends`, `proposals.list`, `cloudflare.status`, `cloudflare.zone.list`, `cloudflare.token.health` |
| `media-consumer` | `MAILROOM_BRIDGE_MEDIA_TOKEN` | `media.health.check`, `media.service.status`, `media.nfs.verify` |
| `task-automation` | `MAILROOM_BRIDGE_TASK_TOKEN` | `mailroom.task.enqueue`, `mailroom.task.claim`, `mailroom.task.heartbeat`, `mailroom.task.complete`, `mailroom.task.fail` |
| `mint-voice` | `MAILROOM_BRIDGE_N8N_MORPHEUS_VOICE_TOKEN` | `mint.customer.voice.intake.capture`, `mint.customer.voice.callback.enqueue`, `mint.customer.frontdesk.facts.get` |

Update path:
- `bash ops/plugins/infra/mailroom-bridge/bin/mailroom-bridge-consumers-sync`
<!-- AUTO: BRIDGE_CONSUMERS_END -->
