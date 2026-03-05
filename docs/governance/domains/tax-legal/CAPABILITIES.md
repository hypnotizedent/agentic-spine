---
status: active
owner: "@ronny"
created: "2026-03-03"
updated: "2026-03-05"
scope: domain-capability-catalog
domain: tax-legal
gap: GAP-OP-1432
loop: LOOP-TAXLEGAL-W2-RUNTIME-IMPLEMENTATION-20260305
---

# tax-legal Capability Catalog

Core capabilities registered in `ops/capabilities.yaml` (Wave 2). Remaining capabilities planned for future waves.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `taxlegal.case.intake` | `mutating` | `auto` | active |
| `taxlegal.case.status` | `read-only` | `auto` | active |
| `taxlegal.case.closeout` | `mutating` | `manual` | planned |
| `taxlegal.sources.sync` | `mutating` | `manual` | planned |
| `taxlegal.sources.diff` | `read-only` | `auto` | planned |
| `taxlegal.research.answer` | `read-only` | `auto` | active |
| `taxlegal.research.compare` | `read-only` | `auto` | planned |
| `taxlegal.deadlines.refresh` | `mutating` | `auto` | active |
| `taxlegal.deadlines.status` | `read-only` | `auto` | active |
| `taxlegal.packet.generate` | `mutating` | `auto` | active |
| `taxlegal.memo.attorney_cpa` | `mutating` | `auto` | planned |
| `taxlegal.privacy.scan` | `read-only` | `auto` | planned |
| `taxlegal.privacy.redact` | `mutating` | `manual` | planned |
| `taxlegal.retention.enforce` | `mutating` | `manual` | planned |
