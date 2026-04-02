# core

Canonical domain policy for `core`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/core.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain core`

## Governed Capability Membership

- Total governed capabilities with `domain: core`: `91`
- `89` are `plane: fabric` capabilities
- `2` are `plane: domain_external` capabilities listed in the catalog block below: `translator.ingest`, `translator.status`
- The catalog view shows only the `domain_external` capabilities; the `89` fabric capabilities are engine-internal

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `translator.ingest` |
| `translator.status` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
