# communications-agent Contract

> **Status:** active
> **Domain:** communications
> **Owner:** @ronny
> **Created:** 2026-02-21
> **Loop:** LOOP-AGENT-MCP-SURFACE-BUILD-20260221

---

## Identity

- **Agent ID:** communications-agent
- **Domain:** communications (transactional email/SMS governance + mailbox operations)
- **MCP Type:** gateway (wraps spine capabilities via subprocess)
- **MCP Server:** `~/code/workbench/agents/communications/tools/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Transactional message route policy | Spine communications contracts |
| Preview-before-send execution boundary | Spine communications preview/execute linkage |
| Phased live cutover control (Resend/Twilio) | Spine communications provider contract |
| Provider routing (Graph/Resend/Twilio) | Spine communications plugin |
| Consent/compliance checks | Spine communications policy contract |
| Delivery artifact normalization | Spine communications delivery contract |
| Delivery anomaly alerting | Spine communications anomaly status/dispatch surfaces |

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
- `communications.delivery.anomaly.status`
- `communications.delivery.anomaly.dispatch`
- `communications.alerts.flush`
- `communications.alerts.queue.status`
- `communications.alerts.queue.slo.status`

## Alert Intent Queue Triage

Operator workflow for alert-intent queue health:

1. **Probe**: `alerting.dispatch` writes intents to `mailroom/outbox/alerts/email-intents/`
2. **Status**: `communications.alerts.queue.status` shows pending/sent/failed counts and ages
3. **SLO**: `communications.alerts.queue.slo.status` evaluates queue against SLO thresholds (ok/warn/incident)
4. **Flush**: `communications.alerts.flush` sends pending intents (manual approval boundary)

SLO contract: `ops/bindings/communications.alerts.queue.contract.yaml`

## Invocation

On-demand via Claude Desktop MCP gateway server, or route via `agent.route` using communications keywords, or use communications capabilities directly via `ops cap run`.
