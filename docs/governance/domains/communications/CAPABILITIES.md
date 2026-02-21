---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: domain-capability-catalog
domain: communications
---

# communications Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `communications.delivery.anomaly.dispatch` | `mutating` | `manual` | `ops/plugins/communications/` |
| `communications.delivery.anomaly.status` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.delivery.log` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.mail.search` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.mail.send.test` | `mutating` | `manual` | `ops/plugins/communications/` |
| `communications.mailboxes.list` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.policy.status` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.provider.status` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.send.execute` | `mutating` | `manual` | `ops/plugins/communications/` |
| `communications.send.preview` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.stack.status` | `read-only` | `auto` | `ops/plugins/communications/` |
| `communications.templates.list` | `read-only` | `auto` | `ops/plugins/communications/` |
