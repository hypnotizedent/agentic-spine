---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-18
scope: aof-surface-readonly-contract
---

# AOF Surface Readonly Contract

> Declares readonly surface endpoints for operational visibility.

## Surface Inventory

| Surface | Capability | Format | Access | Status |
|---------|-----------|--------|--------|--------|
| Spine Status | `spine.status` | text | local | Exists |
| Gap Reconciliation | `gaps.status` | text | local | Exists |
| Loop Summary | `loops.status` | text | local | Exists |
| RAG Status | `rag.anythingllm.status` | text | local | Exists |
| Proposal Queue | `proposals.status` | text | local | Exists |
| Mobile Dashboard | `surface.mobile.dashboard.status` | json | remote | Exists |

## Access Model

- All surfaces are **read-only** — no mutations through surface endpoints
- `local` access: CLI execution on spine host
- `remote` access: API endpoint (requires authentication)

## Mobile Dashboard

The mobile/customer dashboard surface aggregates:
- Spine status (loops, gaps, proposals)
- Gate pass/fail summary
- RAG parity status

Implemented via `surface.mobile.dashboard.status` and exposed through bridge Cap-RPC allowlists for remote read-only consumption.

## Enforcement

- **Binding**: `ops/bindings/surface.readonly.contract.yaml`
- **Gate**: D97 (surface-readonly-contract-lock)
- **Capability**: `surface.readonly.audit` (read-only compliance check)
