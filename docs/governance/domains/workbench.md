# workbench

Canonical domain policy for `workbench`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/workbench.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain workbench`

## Governed Capability Membership

- Total governed capabilities with `domain: workbench`: `5`
- All `5` are `plane: fabric` capabilities
- `0` are `plane: domain_external` capabilities
- The catalog view shows only `domain_external` capabilities; all `5` fabric capabilities are engine-internal

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `workbench`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
