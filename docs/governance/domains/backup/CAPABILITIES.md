---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: domain-capability-catalog
domain: backup
---

# backup Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `backup.calendar.generate` | `read-only` | `auto` | `docs/infrastructure/domains/backup/` |
| `backup.status` | `read-only` | `auto` | `docs/infrastructure/domains/backup/` |
| `backup.vzdump.prune` | `mutating` | `manual` | `docs/infrastructure/domains/backup/` |
| `backup.vzdump.run` | `mutating` | `manual` | `docs/infrastructure/domains/backup/` |
| `backup.vzdump.status` | `read-only` | `auto` | `docs/infrastructure/domains/backup/` |
| `backup.vzdump.vmid.set` | `mutating` | `manual` | `docs/infrastructure/domains/backup/` |
