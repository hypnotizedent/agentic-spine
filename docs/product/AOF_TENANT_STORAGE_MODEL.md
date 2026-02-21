---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-18
scope: aof-tenant-storage-model
---

# AOF Tenant Storage Model

> Defines how AOF isolates tenant data across runtime storage paths.

## Storage Boundaries

AOF manages 5 storage boundaries that contain tenant-scoped data:

| Boundary | Current Path | Sensitivity | Tenant Template |
|----------|-------------|-------------|-----------------|
| Receipts | `receipts/sessions/` | high | `receipts/tenants/{tenant_id}/sessions/` |
| Ledger | `receipts/ledger/` | high | `receipts/tenants/{tenant_id}/ledger/` |
| Inbox | `mailroom/inbox/` | medium | `mailroom/tenants/{tenant_id}/inbox/` |
| Outbox | `mailroom/outbox/` | medium | `mailroom/tenants/{tenant_id}/outbox/` |
| Loop Scopes | `mailroom/state/loop-scopes/` | low | `mailroom/tenants/{tenant_id}/state/loop-scopes/` |

Current baseline parity: `receipts/ledger/` path is now provisioned in-repo (`receipts/ledger/.keep`) for contract-complete boundary checks.

## Isolation Modes

- **Logical** (current): Shared filesystem, tenant-prefixed paths. Single-tenant deployments use flat paths.
- **Physical** (planned): Separate volumes or namespaces per tenant. Requires infrastructure provisioning.

## Enforcement

- **Binding**: `ops/bindings/tenant.storage.contract.yaml`
- **Gate**: D93 (tenant-storage-boundary-lock)
- **Capability**: `tenant.storage.audit` (read-only boundary verification)

## Constraints

- No runtime path writes outside declared boundaries
- High-sensitivity paths require evidence retention policy compliance
- Tenant path templates must include `{tenant_id}` placeholder
