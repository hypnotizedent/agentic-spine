---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: domain-capability-catalog
domain: n8n
---

# n8n Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `n8n.infra.health` | `read-only` | `auto` | `agents/n8n/` |
| `n8n.workflows.activate` | `mutating` | `manual` | `agents/n8n/tools/src/` |
| `n8n.workflows.deactivate` | `mutating` | `manual` | `agents/n8n/tools/src/` |
| `n8n.workflows.delete` | `destructive` | `manual` | `agents/n8n/tools/src/` |
| `n8n.workflows.export` | `mutating` | `auto` | `agents/n8n/tools/src/` |
| `n8n.workflows.get` | `read-only` | `auto` | `agents/n8n/tools/src/` |
| `n8n.workflows.import` | `mutating` | `manual` | `agents/n8n/tools/src/` |
| `n8n.workflows.list` | `read-only` | `auto` | `agents/n8n/` |
| `n8n.workflows.snapshot` | `mutating` | `auto` | `agents/n8n/tools/src/` |
| `n8n.workflows.snapshot.status` | `read-only` | `auto` | `agents/n8n/tools/src/` |
| `n8n.workflows.update` | `mutating` | `manual` | `agents/n8n/tools/src/` |
