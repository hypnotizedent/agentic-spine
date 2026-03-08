# proxmox-network

Canonical domain policy for `proxmox-network`.

- **Doctrine**: `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md` (non-negotiable VM lifecycle, offsite, and destructive-operation rules)
- **Operator Checklist**: `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md` (practical VM/offsite decision checklist)
- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/proxmox-network.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain proxmox-network`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

_No domain-external capabilities currently map to `proxmox-network`._
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
