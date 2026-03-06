# backup

Canonical domain policy for `backup`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/backup.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain backup`

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
