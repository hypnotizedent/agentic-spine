---
status: planned
owner: "@ronny"
created: "2026-03-03"
scope: domain-capability-catalog
domain: tax-legal
gap: GAP-OP-1432
loop: LOOP-TAXLEGAL-W1-DOMAIN-ROUTING-INTEGRATION-20260303
---

# tax-legal Capability Catalog

Planned capabilities for the tax-legal domain. Not yet registered in `ops/capabilities.yaml`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `taxlegal.case.intake` | `mutating` | `auto` | planned |
| `taxlegal.case.status` | `read-only` | `auto` | planned |
| `taxlegal.case.closeout` | `mutating` | `manual` | planned |
| `taxlegal.sources.sync` | `mutating` | `manual` | planned |
| `taxlegal.sources.diff` | `read-only` | `auto` | planned |
| `taxlegal.research.answer` | `read-only` | `auto` | planned |
| `taxlegal.research.compare` | `read-only` | `auto` | planned |
| `taxlegal.deadlines.refresh` | `mutating` | `auto` | planned |
| `taxlegal.deadlines.status` | `read-only` | `auto` | planned |
| `taxlegal.packet.generate` | `mutating` | `auto` | planned |
| `taxlegal.memo.attorney_cpa` | `mutating` | `auto` | planned |
| `taxlegal.privacy.scan` | `read-only` | `auto` | planned |
| `taxlegal.privacy.redact` | `mutating` | `manual` | planned |
| `taxlegal.retention.enforce` | `mutating` | `manual` | planned |
