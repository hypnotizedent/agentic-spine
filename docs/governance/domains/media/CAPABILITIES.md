---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: domain-capability-catalog
domain: media
---

# media Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `media.backup.create` | `mutating` | `manual` | `agents/media/tools/src/` |
| `media.health.check` | `read-only` | `auto` | `agents/media/tools/src/` |
| `media.metrics.today` | `read-only` | `auto` | `agents/media/` |
| `media.nfs.verify` | `read-only` | `auto` | `agents/media/tools/src/` |
| `media.service.status` | `read-only` | `auto` | `agents/media/tools/src/` |
| `media.stack.restart` | `mutating` | `manual` | `agents/media/tools/src/` |
| `media.status` | `read-only` | `auto` | `agents/media/tools/src/` |
| `recyclarr.sync` | `mutating` | `manual` | `agents/media/` |
