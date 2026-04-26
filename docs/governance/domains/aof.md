# aof

Canonical fabric grouping for `aof`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/aof.bundle.yaml`
- Verification posture: `./bin/ops cap run spine.verify`

## Governed Capability Membership

- `aof` is not a live runtime verify domain
- Current fabric surfaces in this grouping are carried by `tenant.*`, `policy.*`, `version.*`, `surface.*`, `evidence.*`, and `receipts.*`
- `0` domain-external capabilities currently map to `aof`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities map to `aof`; use the grouped fabric surfaces above._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
