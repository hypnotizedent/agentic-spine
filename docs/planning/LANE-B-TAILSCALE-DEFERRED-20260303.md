# Lane B Report: Tailscale Integration Deferred Actions

- **Lane**: B
- **Plan**: PLAN-TAILSCALE-INTEGRATION-DEFERRED-ACTIONS
- **Parent Loop**: LOOP-NEXT-WAVE-6PLAN-EXECUTION-20260303
- **Source Loop**: LOOP-TAILSCALE-INTEGRATION-DEFERRED-ACTIONS-20260302
- **Date**: 2026-03-03
- **Worker**: Lane B subagent

## Objective

Create spec/contract artifacts for the two externally-blocked Tailscale integration
deferred actions (webhook receiver and audit log streaming) so that deployment can
proceed immediately once infrastructure blockers are resolved.

## Outcome: completed

All deliverables produced. Both gaps remain OPEN because they are blocked on external
infrastructure that cannot be resolved by spec work alone.

## Artifacts Created

### 1. Webhook Receiver Contract
- **File**: `ops/bindings/tailscale.webhook.receiver.contract.yaml`
- **Content**: Endpoint URL convention (n8n preferred at `https://n8n.ronny.works/webhook/tailscale`),
  4 event types to subscribe (nodeCreated, nodeDeleted, nodeKeyExpiringInOneDay, policyUpdate),
  HMAC-SHA256 auth pattern with Infisical-stored webhook secret, exponential backoff retry policy,
  n8n workflow integration spec with signature verification and event routing nodes,
  full deployment checklist with prerequisite chain.

### 2. Audit Log Collection Contract
- **File**: `ops/bindings/tailscale.audit.log.contract.yaml`
- **Content**: Collection strategy (admin console streaming -- no API exists, confirmed 404),
  Grafana Loki on observability-stack (VM 205) as primary log destination,
  30/90/365-day tiered retention policy, JSON format spec,
  freshness-based drift detection (since no API exists for config verification),
  full deployment checklist.

### 3. Webhook Receiver Capability Stub
- **File**: `ops/capabilities/tailscale-webhook-receiver.yaml`
- **Lifecycle**: planned
- **Capability ID**: `tailscale.webhook.receiver.status`
- **Purpose**: Health check for deployed webhook receiver endpoint
- **Activation**: Manual, after receiver deployment and subscription creation

### 4. Audit Log Collection Capability Stub
- **File**: `ops/capabilities/tailscale-audit-log-collect.yaml`
- **Lifecycle**: planned
- **Capability IDs**: `tailscale.audit.log.freshness` (primary), `tailscale.audit.log.query` (sibling)
- **Purpose**: Freshness monitoring for audit log stream via Loki queries
- **Activation**: Manual, after Loki provisioning and admin console streaming config

## Gaps Addressed

| Gap ID | Title | Status | Notes |
|--------|-------|--------|-------|
| GAP-OP-1259 | Tailscale webhook receiver not deployed | OPEN (spec ready) | Blocked: VM 202 unreachable, n8n deployment required. Contract and capability stub created. Deployment can proceed immediately once VM 202 is restored. |
| GAP-OP-1260 | Tailscale audit log streaming not configured | OPEN (spec ready) | Blocked: No API exists (admin console only), no log destination provisioned. Contract and capability stub created. Requires Loki provisioning on VM 205 + manual admin console config. |

## Blockers

### GAP-OP-1259 Blockers
1. **automation-stack (VM 202) unreachable** -- Cannot deploy webhook receiver (n8n or dedicated service)
   until VM 202 connectivity is restored.
2. **n8n webhook workflow not created** -- Depends on VM 202 availability.

### GAP-OP-1260 Blockers
1. **No Tailscale API for audit log streaming** -- Confirmed 404 on `/logging` and `/log-stream`
   endpoints. Configuration is admin-console-only. This is a permanent external constraint
   (no ETA from Tailscale for API support).
2. **Grafana Loki not provisioned for tailscale-audit** -- Loki exists on observability-stack
   (VM 205) but has no label/tenant configured for tailscale audit log ingestion.

## Relationship to Existing Capabilities

The following capabilities already exist and are functional:

| Capability | Status | Purpose |
|-----------|--------|---------|
| `tailscale.webhook.subscribe` | ready | Create/list webhook subscriptions via OAuth API |
| `tailscale.audit.status` | ready | Report audit log streaming prerequisites |
| `tailscale.integration.status` | ready | Aggregated status of all integration components |

The new capability stubs (`tailscale.webhook.receiver.status`, `tailscale.audit.log.freshness`,
`tailscale.audit.log.query`) complement the existing capabilities by adding health monitoring
for the receiver/destination infrastructure that does not yet exist.

## Next Steps (when blockers clear)

### Webhook Receiver (GAP-OP-1259)
1. Restore VM 202 connectivity
2. Deploy n8n webhook workflow per contract spec
3. Run `./bin/ops cap run tailscale.webhook.subscribe -- --action create --endpoint https://n8n.ronny.works/webhook/tailscale`
4. Store webhook secret in Infisical
5. Implement `tailscale-webhook-receiver-status` script
6. Register in `ops/capabilities.yaml` with `lifecycle: ready`
7. Close GAP-OP-1259

### Audit Log Streaming (GAP-OP-1260)
1. Provision Loki label/tenant for `tailscale-audit` on VM 205
2. Configure streaming in Tailscale admin console (JSON format)
3. Verify first log entry arrives in Loki
4. Implement `tailscale-audit-log-freshness` script
5. Register in `ops/capabilities.yaml` with `lifecycle: ready`
6. Create Grafana dashboard for audit log queries
7. Close GAP-OP-1260
