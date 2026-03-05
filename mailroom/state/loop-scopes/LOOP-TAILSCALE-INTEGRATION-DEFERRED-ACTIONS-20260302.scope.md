---
loop_id: LOOP-TAILSCALE-INTEGRATION-DEFERRED-ACTIONS-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: tailscale
priority: medium
horizon: now
execution_mode: orchestrator_subagents
execution_readiness: blocked
next_review: "2026-04-01"
activation_trigger: manual
blocked_by: "no-audit-log-destination"
superseded_by_plan_id: PLAN-TAILSCALE-INTEGRATION-DEFERRED-ACTIONS
migrated_at_utc: "2026-03-02T00:30:00Z"
objective: "Track deferred operator actions for webhook receiver and audit-log streaming enablement"
---

# Loop Scope: LOOP-TAILSCALE-INTEGRATION-DEFERRED-ACTIONS-20260302

## Objective

Track deferred operator actions for webhook receiver and audit-log streaming enablement

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Webhook status**: `./bin/ops cap run tailscale.webhook.subscribe -- --action status`
- **Audit status**: `./bin/ops cap run tailscale.audit.status`
- **Integration status**: `./bin/ops cap run tailscale.integration.status`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-TAILSCALE-INTEGRATION-DEFERRED-ACTIONS-20260302`

## Phases

- Step 0: (DONE) Create capability stubs for webhook subscribe and audit status
- Step 1: Provision webhook receiver endpoint (n8n workflow or dedicated service on automation-stack VM 202)
- Step 2: Create webhook subscription via `tailscale.webhook.subscribe -- --action create --endpoint <URL>`
- Step 3: Provision audit log destination (Grafana Loki on observability-stack VM 205)
- Step 4: Configure audit log streaming via admin console (no API available)
- Step 5: Complete OP-TS-001 and OP-TS-002, close GAP-OP-1259 and GAP-OP-1260

## Current State (2026-03-03)

### GAP-OP-1259: Webhook receiver deployment + subscription
- **Status**: completed (closed as fixed)
- **Capability**: `tailscale.webhook.subscribe`
- **API confirmed**: POST /api/v2/tailnet/{tailnet}/webhooks exists and is accessible via OAuth
- **Events to subscribe**: nodeCreated, nodeDeleted, nodeKeyExpiringInOneDay, policyUpdate
- **Receiver**: `https://tailscale-webhook.ronny.works/tailscale` (dedicated receiver on automation-stack)
- **Subscription**: active (`webhook_count=1`, endpoint_id `wNcKgtrx2S11CNTRL`)
- **Evidence**: `mailroom/state/tailscale-audit/webhook-receiver-deploy-20260305.yaml`

### GAP-OP-1260: Audit log streaming not configured
- **Status**: stub_ready (capability created, blocked on external dependency)
- **Capability**: `tailscale.audit.status` (reports current state and prerequisites)
- **API confirmed**: Does NOT exist (404 on /logging and /log-stream) -- admin console only
- **Blocker**: (1) No log destination provisioned, (2) No API for automation
- **Next runnable**: Provision Grafana Loki on observability-stack, then configure via https://admin.tailscale.com/admin/settings/logs

## Deployment Prerequisites

### Webhook Receiver (GAP-OP-1259)
1. Confirm automation-stack (VM 202) is healthy: `ssh automation@192.168.1.110`
2. Deploy webhook receiver:
   - **Option A (preferred)**: n8n webhook node at `https://n8n.ronny.works/webhook/tailscale`
   - **Option B**: Dedicated lightweight HTTP receiver in a container
3. Ensure endpoint is publicly reachable (HTTPS required by Tailscale API)
4. Run: `./bin/ops cap run tailscale.webhook.subscribe -- --action create --endpoint <URL>`
5. Store returned webhook secret in Infisical at `/spine/vm-infra/provisioning` as `TAILSCALE_WEBHOOK_SECRET`

### Audit Log Streaming (GAP-OP-1260)
1. Provision log destination on observability-stack (VM 205):
   - **Option A (preferred)**: Grafana Loki (already deployed on observability-stack)
   - **Option B**: S3 bucket
2. Configure streaming in Tailscale admin console (manual, no API)
3. Set format to JSON
4. Verify first log entry appears at destination

## Success Criteria
- Webhook receiver deployed and webhook subscription active (verified via `tailscale.webhook.subscribe -- --action status`)
- Audit log streaming configured with destination evidence
- GAP-OP-1259 and GAP-OP-1260 closed

## Definition Of Done
- Open gaps reparented and non-orphaned
- Both capabilities (`tailscale.webhook.subscribe`, `tailscale.audit.status`) in lifecycle: ready
- Authority contract updated with active status for both integrations
