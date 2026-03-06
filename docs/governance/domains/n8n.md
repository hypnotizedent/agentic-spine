# n8n

Canonical domain policy for `n8n`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/n8n.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain n8n`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `n8n.infra.health` |
| `n8n.infra.health.quick` |
| `n8n.workflows.activate` |
| `n8n.workflows.deactivate` |
| `n8n.workflows.delete` |
| `n8n.workflows.export` |
| `n8n.workflows.get` |
| `n8n.workflows.import` |
| `n8n.workflows.list` |
| `n8n.workflows.snapshot` |
| `n8n.workflows.snapshot.status` |
| `n8n.workflows.update` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
