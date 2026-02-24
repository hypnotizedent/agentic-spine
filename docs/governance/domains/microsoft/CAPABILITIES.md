---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: domain-capability-catalog
domain: microsoft
---

# microsoft Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `microsoft.calendar.create` | `mutating` | `manual` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.calendar.get` | `read-only` | `auto` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.calendar.list` | `read-only` | `auto` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.calendar.rsvp` | `mutating` | `manual` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.calendar.update` | `mutating` | `manual` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.mail.draft.create` | `mutating` | `manual` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.mail.draft.update` | `mutating` | `manual` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.mail.get` | `read-only` | `auto` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.mail.search` | `read-only` | `auto` | `agents/microsoft/tools/microsoft_tools.py` |
| `microsoft.mail.send` | `mutating` | `manual` | `agents/microsoft/tools/microsoft_tools.py` |
