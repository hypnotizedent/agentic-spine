---
status: authoritative
owner: "@ronny"
last_reviewed: 2026-02-15
scope: ha-mcp-integration-policy
---

# Home Assistant MCP Integration Policy

## Summary

Home Assistant exposes an MCP server (`homeassistant`) with a `ha_call_service` tool.
This tool is **blocked** for agent use. Agents must use scoped spine capabilities instead.

## Why MCP Pass-Through Is Blocked

1. **No domain allowlist.** MCP `ha_call_service` accepts any domain/service pair, including
   destructive operations (e.g., `homeassistant.restart`, `script.turn_on` with arbitrary scripts).
   Spine capabilities enforce a 6-domain allowlist: `light`, `scene`, `lock`, `script`, `switch`, `automation`.

2. **No approval workflow.** MCP tools execute immediately. Spine capabilities have per-cap
   approval levels (`auto` for idempotent operations like scenes, `manual` for physical security
   like locks and backups).

3. **No receipt trail.** MCP calls are not logged in the spine receipt ledger.
   Spine capabilities auto-generate receipts for every execution.

4. **No secret isolation.** MCP uses the HA long-lived access token configured at desktop level.
   Spine capabilities resolve tokens via Infisical with project-scoped access.

## Approved Agent Path

Agents must use `ops cap run ha.<capability>` for all HA interactions:

| Capability | Domain | Approval |
|------------|--------|----------|
| `ha.service.call` | any (allowlist) | manual |
| `ha.scene.activate` | scene | auto |
| `ha.light.toggle` | light | auto |
| `ha.lock.control` | lock | manual |
| `ha.automation.trigger` | automation | auto |
| `ha.script.run` | script | auto |
| `ha.backup.create` | n/a (SSH) | manual |
| `ha.device.map.build` | n/a (read-only) | auto |

## MCP Server Configuration

The Home Assistant MCP server remains registered in Claude Desktop config for **read-only**
context (entity state queries). The `ha_call_service` tool is denied by MCP domain deny policy
in `ops/capabilities.yaml` (line 1596).

## Future Considerations

If MCP gains per-tool approval and audit capabilities, the deny policy can be revisited.
Until then, all mutating HA operations flow through spine capabilities exclusively.
