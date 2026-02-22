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
- `communications.alerts.queue.escalate`
- `communications.alerts.runtime.status`

## Watcher First Triage

Standard operator triage flow when investigating communications health:

1. **Check watcher/status line**: Run `./bin/ops status` or `./bin/ops cap run spine.watcher.status` and look for the `CommsQueue:` line. If it shows `ok`, no action needed.
2. **Drill into runtime status**: `./bin/ops cap run communications.alerts.runtime.status` (or `--json` for machine-readable). Review pending count, SLO status, escalation state, and delivery summary.
3. **Escalate (manual)**: If status is `incident`, run `echo "yes" | ./bin/ops cap run communications.alerts.queue.escalate --execute` to create governed escalation artifacts.
4. **Flush (manual)**: Run `echo "yes" | ./bin/ops cap run communications.alerts.flush --limit 10` to send pending intents. This is a manual approval boundary.
5. **Verify delivery**: Run `./bin/ops cap run communications.delivery.log --limit 10` to confirm sends landed.

## Alert Intent Queue Triage

Operator workflow for alert-intent queue health:

1. **Probe**: `alerting.dispatch` writes intents to `mailroom/outbox/alerts/email-intents/`
2. **Status**: `communications.alerts.queue.status` shows pending/sent/failed counts and ages
3. **SLO**: `communications.alerts.queue.slo.status` evaluates queue against SLO thresholds (ok/warn/incident)
4. **Flush**: `communications.alerts.flush` sends pending intents (manual approval boundary)

SLO contract: `ops/bindings/communications.alerts.queue.contract.yaml`

## Incident Escalation Playbook

When the alert-intent queue SLO status reaches **incident**, use this playbook:

### Step 1: Assess queue state

```bash
./bin/ops cap run communications.alerts.queue.status --json
```

Review pending count, oldest age, and top pending intents.

### Step 2: Confirm SLO breach

```bash
./bin/ops cap run communications.alerts.queue.slo.status --json
```

Check `escalation_recommended`, `escalation_reason`, and `escalation_fingerprint` fields.

### Step 3: Create governed escalation artifacts

```bash
echo "yes" | ./bin/ops cap run communications.alerts.queue.escalate --execute
```

This writes:
- Escalation artifact to `mailroom/outbox/alerts/communications/escalations/`
- Governed mailroom task (route target: communications)
- Proposal skeleton (draft, requires manual submit)

The escalation has cooldown-based dedupe (default 1800s). Repeated runs within the cooldown window for the same fingerprint are no-ops.

### Step 4: Flush pending intents (manual)

```bash
echo "yes" | ./bin/ops cap run communications.alerts.flush --limit 10
```

This sends real email. Manual approval boundary is preserved.

### Step 5: Verify delivery

```bash
./bin/ops cap run communications.delivery.log --limit 10
```

### Step 6: Root-cause follow-up

Investigate backlog cause:
- Provider issues: `./bin/ops cap run communications.provider.status`
- Policy blocks: `./bin/ops cap run communications.policy.status`
- Throughput analysis: check pending count trend over time
- Review escalation task in mailroom for follow-up actions

Escalation contract: `ops/bindings/communications.alerts.escalation.contract.yaml`

## Invocation

On-demand via Claude Desktop MCP gateway server, or route via `agent.route` using communications keywords, or use communications capabilities directly via `ops cap run`.
