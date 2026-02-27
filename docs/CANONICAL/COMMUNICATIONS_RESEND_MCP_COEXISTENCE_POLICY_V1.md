---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-27
scope: resend-mcp-coexistence-policy
parent_loop: LOOP-SPINE-RESEND-CANONICAL-UPGRADE-20260227-20260301-20260227
gate_enforcement: D257, D262
---

# Communications Resend MCP Coexistence Policy V1

## Purpose

Define the boundary between the **spine communications gateway** (existing, authoritative for transactional sends) and the **Resend MCP server v2.1** (new, expansion surface for read-only operations and governed mutations).

## Core Principle

**Transactional send authority is spine-only.** The Resend MCP server MUST NOT be used for production transactional email sends. All customer-facing email dispatch routes through `communications.send.preview` then `communications.send.execute`.

## Architecture

```
Claude Desktop / Claude Code
  |
  |--- spine MCP gateway (communications-agent)
  |      |--- communications.send.preview   (transactional - AUTHORITATIVE)
  |      |--- communications.send.execute   (transactional - AUTHORITATIVE)
  |      |--- communications.provider.status (read-only)
  |      |--- communications.delivery.log   (read-only)
  |      |--- [13 more governed capabilities]
  |
  |--- Resend MCP server v2.1 (EXPANSION - read + governed mutations)
         |--- list_emails          (READ - allowed)
         |--- get_email            (READ - allowed)
         |--- list_received_emails (READ - allowed)
         |--- read_received_email  (READ - allowed)
         |--- list_contacts        (READ - allowed)
         |--- get_contact          (READ - allowed)
         |--- create_contact       (GOVERNED - manual approval)
         |--- send_email           (FORBIDDEN - spine authority)
         |--- batch_send_emails    (FORBIDDEN - spine authority)
         |--- send_broadcast       (FORBIDDEN - requires gate D260)
```

## Tool Classification

### Allowed (read-only, no approval needed)

| Tool | Scope |
|------|-------|
| `list_emails` | Read delivery status of sent emails |
| `get_email` | Read single email details |
| `list_received_emails` | Read inbound email list |
| `read_received_email` | Read single inbound email |
| `list_received_email_attachments` | List inbound attachments |
| `download_received_email_attachment` | Download inbound attachment |
| `list_contacts` | Read audience contacts |
| `get_contact` | Read single contact |
| `list_domains` | Read domain configuration |
| `get_domain` | Read domain verification status |
| `list_broadcasts` | Read campaign list |
| `get_broadcast` | Read single campaign |
| `list_segments` | Read audience segments |
| `list_topics` | Read subscription topics |

### Governed (manual approval required)

| Tool | Gate | Condition |
|------|------|-----------|
| `create_contact` | D259 | Manual approval, suppression check |
| `update_contact` | D259 | Manual approval |
| `remove_contact` | D259 | Manual approval |
| `create_webhook` | D258 | Manual approval, schema validation |

### Forbidden (spine authority or infrastructure mutation)

| Tool | Reason |
|------|--------|
| `send_email` | Transactional send authority is spine-only (D257) |
| `batch_send_emails` | Transactional send authority is spine-only (D257) |
| `create_broadcast` | Requires broadcast governance gate (D260) |
| `send_broadcast` | Requires broadcast governance gate (D260) |
| `create_api_key` | Infrastructure mutation |
| `remove_api_key` | Infrastructure mutation |
| `create_domain` | Infrastructure mutation |
| `remove_domain` | Infrastructure mutation |
| `update_domain` | Infrastructure mutation |

## Enforcement

1. **D257** (resend-mcp-transactional-send-authority-lock): Validates no direct Resend MCP `send_email` or `batch_send_emails` calls exist in governed paths.
2. **D262** (communications-resend-expansion-contract-parity-lock): Validates this policy document and the expansion contract are present and consistent.
3. **D147** (existing): Validates no direct `api.resend.com` calls outside `ops/plugins/communications/`.

## Installation Guidance

When the Resend MCP server is added to Claude Desktop config, use:

```json
{
  "resend": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "resend-mcp"],
    "env": {
      "RESEND_API_KEY": "<from-infisical>"
    }
  }
}
```

The `RESEND_API_KEY` is sourced from Infisical at path `/spine/services/communications` in project `infrastructure`, environment `prod`.

## Promotion Path

1. **Current (W53)**: Policy documented, gates in report mode, no MCP server installed yet.
2. **Next wave**: Install Resend MCP server in Claude Desktop with read-only scope.
3. **Future wave**: Enable governed mutations (contacts) after D259 passes in enforce mode.
4. **Future wave**: Enable broadcast surface after D260 passes in enforce mode.
