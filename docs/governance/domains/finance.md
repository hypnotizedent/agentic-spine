# finance

Canonical domain policy for `finance`.

- **Doctrine**: `ops/bindings/domains/finance.bundle.yaml` and `ops/bindings/domains/backup/backup.inventory.yaml`
- **Operator Checklist**: `finance.stack.status` and `backup.status`
- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/finance.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain finance`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `finance.stack.status` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
