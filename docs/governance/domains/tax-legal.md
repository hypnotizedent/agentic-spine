# tax-legal

Canonical domain policy for `tax-legal`.

- Authority: `docs/governance/SPINE.md`
- **Canonical home:** subsurface inside `workbench/agents/finance/` (tax/compliance/legal-research)
- **Spine mode:** projection (spine holds engine registrations; product truth governed under finance agent)
- Runtime contracts: `ops/bindings/domains/tax-legal.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain tax-legal`
- Runtime namespace: capability ids remain `taxlegal.*`. Plugin and binding paths removed from spine (Packet 4: TAXLEGAL-FINANCE-SUBSURFACE-DELIVERY). Product contracts now live at `workbench/agents/finance/bindings/taxlegal/`.

## Canonical Home Decision

Decided 2026-04-25 (Packet 3: CANONICAL-HOME-MATRIX).

Tax-legal is a sub-concern of finance, not an independent domain runtime.
Product truth (1099 prep, DR-15 prep, finance compliance cadence,
receipt/document retrieval, legal research) is governed under
`workbench/agents/finance/`. Case envelopes remain modeled under
`runtime/domain-state/taxlegal/cases`, canonical documents live in
Paperless-NGX under the case tag, case-bound PII refs stay under the finance
sub-namespace `/spine/services/finance/taxlegal/`, and Paperless auth remains
under `/spine/services/paperless/`. No standalone `/spine/services/taxlegal/`
namespace is justified by the current shape. Spine retains engine registrations
(bundle, capability registry) as L1/L2 infrastructure. All 10 domain binding
contracts and 1 stub script extracted.

No standalone `workbench/agents/tax-legal/` directory is justified by current
or planned workload. If tax-legal grows into an independent operator surface,
this decision can be revisited with a new canonical-home packet.

## Governed Capability Membership

- Total governed capabilities with `domain: tax-legal`: `8`
- `domain_external` capabilities listed in the catalog block below: `0`
- All currently governed capabilities under this canonical label remain fabric capabilities:
- `taxlegal.case.intake`
- `taxlegal.case.status`
- `taxlegal.deadlines.refresh`
- `taxlegal.deadlines.status`
- `taxlegal.research.answer`
- `taxlegal.packet.generate`
- `taxlegal.source.ingest`
- `taxlegal.source.recall`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `tax-legal`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
