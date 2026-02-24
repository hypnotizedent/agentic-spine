# microsoft-agent Contract

> **Status:** registered
> **Domain:** identity
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** microsoft-agent
- **Domain:** identity (Microsoft API — email, calendar, identity)
- **Workbench Implementation:** `~/code/workbench/agents/microsoft/tools/microsoft_tools.py`
- **MCP Mirror:** `~/code/workbench/infra/compose/mcpjungle/servers/microsoft.json`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Email search/read | Microsoft API |
| Calendar queries | Microsoft API |
| Identity/profile lookups | Microsoft API |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Secrets (OAuth tokens) | Infisical `/spine/services/microsoft/` |

## Governed Tools

Custom governed tools are workbench-owned and invoked through spine capabilities.

### Mail tools

- `mail_search`
- `mail_get`
- `mail_send`
- `draft_create`
- `draft_update`

### Calendar tools

- `calendar_list`
- `calendar_get`
- `calendar_create`
- `calendar_update`
- `calendar_rsvp`

### Sprint guardrail

- Delete/cancel/purge operations remain blocked.

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Microsoft API | graph.microsoft.com | Cloud service (no VM) |
