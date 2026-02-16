# ms-graph-agent Contract

> **Status:** registered
> **Domain:** identity
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** ms-graph-agent
- **Domain:** identity (Microsoft Graph API — email, calendar, identity)
- **Workbench Implementation:** `~/code/workbench/agents/ms-graph/tools/ms_graph_tools.py`
- **MCP Mirror:** `~/code/workbench/infra/compose/mcpjungle/servers/microsoft-graph.json`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Email search/read | MS Graph API |
| Calendar queries | MS Graph API |
| Identity/profile lookups | MS Graph API |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Secrets (OAuth tokens) | Infisical `/spine/services/microsoft-graph/` |

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
| Microsoft Graph API | graph.microsoft.com | Cloud service (no VM) |
