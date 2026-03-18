# Mailroom Bridge — Cap-RPC Consumer Governance

**Status**: authoritative
**Last verified**: 2026-03-17
**Scope**: mailroom-bridge-cap-rpc-rbac

## Overview

The Mailroom Bridge exposes governed capabilities via Cap-RPC over HTTPS.
Consumer access is controlled through role-based access control (RBAC) with scoped token authentication.

## SSOT

- **Registry**: `ops/bindings/mailroom.bridge.consumers.yaml`
- **Runtime binding**: `ops/bindings/mailroom.bridge.yaml`
- **This doc**: Auto-generated from registry

## Consumers

<!-- AUTO: BRIDGE_CONSUMERS_START -->
Bridge Cap-RPC consumers (SSOT: `ops/bindings/mailroom.bridge.consumers.yaml`):

| Role | Token Env | Cap-RPC access |
|------|-----------|----------------|
| `operator` | `MAILROOM_BRIDGE_TOKEN` | \`*\` (full allowlist) |
| `monitor` | `MAILROOM_BRIDGE_MONITOR_TOKEN` | `spine.verify`, `surface.mobile.dashboard.status`, `gaps.status`, `loops.status`, `proposals.status`, `mailroom.bridge.status`, `aof.status`, `aof.version`, `loops.list`, `loops.progress`, `gaps.aging`, `receipts.summary`, `receipts.search`, `receipts.trends`, `proposals.list`, `cloudflare.status`, `cloudflare.zone.list`, `cloudflare.token.health` |
| `media-consumer` | `MAILROOM_BRIDGE_MEDIA_TOKEN` | `media.health.check`, `media.service.status`, `media.nfs.verify` |
| `task-automation` | `MAILROOM_BRIDGE_TASK_TOKEN` | `mailroom.task.enqueue`, `mailroom.task.claim`, `mailroom.task.heartbeat`, `mailroom.task.complete`, `mailroom.task.fail` |
| `n8n-morpheus-voice` | `MAILROOM_BRIDGE_N8N_MORPHEUS_VOICE_TOKEN` | `mint.customer.voice.intake.capture`, `mint.customer.voice.callback.enqueue`, `mint.customer.frontdesk.facts.get`, `mint.customer.order.status.lookup`, `communications.send.preview`, `communications.send.execute` |

Update path:
- `bash ops/plugins/infra/mailroom-bridge/bin/mailroom-bridge-consumers-sync`
<!-- AUTO: BRIDGE_CONSUMERS_END -->

## Adding a New Capability

1. Add capability to `ops/capabilities.yaml`
2. Add capability to `cap_rpc.allowlist` in `mailroom.bridge.consumers.yaml`
3. Optionally create or extend a role with scoped access
4. Run `bash ops/plugins/infra/mailroom-bridge/bin/mailroom-bridge-consumers-sync`
5. Verify with `./bin/ops cap run mailroom.bridge.status`

## Security

- All roles require token authentication via environment variables
- Tokens are scoped per role with explicit capability allow-lists
- `operator` role has full allowlist access (`allow: "*"`)
- Other roles have minimal scoped access

## Related

- [Mailroom Runtime Contract](../ops/bindings/mailroom.runtime.contract.yaml)
- [Cap-RPC Consumer Tests](../../ops/plugins/infra/mailroom-bridge/tests/)
