# communications-agent Contract

> **Status:** registered
> **Domain:** communications
> **Owner:** @ronny
> **Created:** 2026-02-21
> **Loop:** LOOP-SPINE-COMMUNICATIONS-TWILIO-RESEND-NORMALIZATION-V1-20260221

---

## Identity

- **Agent ID:** communications-agent
- **Domain:** communications (transactional email/SMS governance + mailbox operations)
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Transactional message route policy | Spine communications contracts |
| Provider routing (Graph/Resend/Twilio) | Spine communications plugin |
| Consent/compliance checks | Spine communications policy contract |
| Delivery artifact normalization | Spine communications delivery contract |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Capability registry | `ops/capabilities.yaml` |
| Secrets path authority | `ops/bindings/secrets.namespace.policy.yaml` |
| Secrets runway routes | `ops/bindings/secrets.runway.contract.yaml` |
| MCP gateway surface | `ops/plugins/mcp-gateway/bin/spine-mcp-serve` |
| Agent routing and discovery | `ops/plugins/agent/bin/agent-route` |

## Governed Surfaces

- `communications.stack.status`
- `communications.mailboxes.list`
- `communications.mail.search`
- `communications.mail.send.test`
- `communications.provider.status`
- `communications.policy.status`
- `communications.templates.list`
- `communications.send.preview`
- `communications.send.execute`
- `communications.delivery.log`

## Invocation

Route via `agent.route` using communications keywords or use communications capabilities directly via `ops cap run`.
