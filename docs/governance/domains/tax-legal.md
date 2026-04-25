# tax-legal

Canonical domain policy for `tax-legal`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/tax-legal.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain tax-legal`
- Runtime namespace: capability ids remain `taxlegal.*`; live runtime paths remain `ops/plugins/domains/taxlegal/` and `ops/bindings/domains/taxlegal/`.

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
