---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: domain-capability-catalog
domain: n8n
---

# n8n Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `n8n.infra.health` | `read-only` | `auto` | `agents/n8n/` |
| `n8n.infra.health.quick` | `read-only` | `auto` | `agents/n8n/` |
| `n8n.workflows.delete` | `destructive` | `manual` | `agents/n8n/tools/src/` |
| `n8n.workflows.snapshot` | `mutating` | `auto` | `agents/n8n/tools/src/` |
| `n8n.workflows.snapshot.status` | `read-only` | `auto` | `agents/n8n/tools/src/` |
