# home

Canonical domain policy for `home`.

- **Canonical home:** `projects/home/`
- **Doctrine**: `ops/bindings/home.authority.contract.yaml` and `ops/bindings/domains/backup/backup.inventory.yaml`
- **Operator Checklist**: project-local Home Assistant readbacks under `projects/home/tools/` plus `backup.status`
- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/home.bundle.yaml`
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain home`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| Project-local Home Assistant tools live under `projects/home/tools/`; no `home.*` spine capabilities are currently registered. |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
