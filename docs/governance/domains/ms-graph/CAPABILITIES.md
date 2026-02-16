---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: domain-capability-catalog
domain: ms-graph
---

# ms-graph Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `graph.calendar.create` | `mutating` | `manual` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.calendar.get` | `read-only` | `auto` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.calendar.list` | `read-only` | `auto` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.calendar.rsvp` | `mutating` | `manual` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.calendar.update` | `mutating` | `manual` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.mail.draft.create` | `mutating` | `manual` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.mail.draft.update` | `mutating` | `manual` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.mail.get` | `read-only` | `auto` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.mail.search` | `read-only` | `auto` | `agents/ms-graph/tools/ms_graph_tools.py` |
| `graph.mail.send` | `mutating` | `manual` | `agents/ms-graph/tools/ms_graph_tools.py` |
