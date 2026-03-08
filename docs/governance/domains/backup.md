# backup

Canonical domain policy for `backup`.

- **Doctrine**: `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md` (canonical VM primary/offsite/app-level/restore-proof law)
- **Operator Checklist**: `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md` (operator checklist for VM protection and offsite exceptions)
- Authority: `docs/governance/SPINE.md`
- Canonical inventory: `ops/bindings/backup.inventory.yaml`
- Runtime contracts: `ops/bindings/domains/backup.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain backup`

`backup.status` may return `BLOCKED` when a target is present in the canonical
inventory but the current network/auth context cannot probe freshness from this
machine.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `backup.calendar.generate` |
| `backup.monitor` |
| `backup.posture.snapshot.build` |
| `backup.status` |
| `backup.vzdump.mail.policy.set` |
| `backup.vzdump.prune` |
| `backup.vzdump.run` |
| `backup.vzdump.status` |
| `backup.vzdump.vmid.set` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
