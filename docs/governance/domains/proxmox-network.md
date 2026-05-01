# proxmox-network

Canonical domain policy for `proxmox-network`.

- **Doctrine**: `ops/bindings/node.role.contract.yaml`, `ops/bindings/vm.lifecycle.yaml`, and `ops/bindings/domains/backup/backup.inventory.yaml`
- **Operator Checklist**: `node.admission.status`, `node.recovery.status`, and `backup.status`
- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/proxmox-network.bundle.yaml`
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain proxmox-network`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `proxmox-network`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
