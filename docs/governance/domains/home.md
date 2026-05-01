# home

Canonical domain policy for `home`.

- **Doctrine**: `ops/bindings/home.authority.contract.yaml` and `ops/bindings/domains/backup/backup.inventory.yaml`
- **Operator Checklist**: `home.backup.status` and `backup.status`
- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/home.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain home`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `home.backup.status` |
| `home.health.alert` |
| `home.health.check` |
| `home.vm.status` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
