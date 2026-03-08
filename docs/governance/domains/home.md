# home

Canonical domain policy for `home`.

- **Doctrine**: `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md` (defines the home-vs-shop VM backup boundary and home offsite semantics)
- **Operator Checklist**: `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md` (home VM/LXC protection checks)
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
