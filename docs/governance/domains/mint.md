# mint

Canonical domain policy for `mint`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/mint.bundle.yaml`
- Public ingress contract: `ops/bindings/mint.public.ingress.contract.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain mint`
- Public deploy closeout: `mint.modules.health` -> `mint.runtime.proof` -> `mint.public.ingress.proof` -> `mint.public.canary`

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `mint.deploy.promote` |
| `mint.deploy.status` |
| `mint.deploy.sync` |
| `mint.intake.validate` |
| `mint.live.baseline.status` |
| `mint.loop.daily` |
| `mint.migrate.dryrun` |
| `mint.modules.health` |
| `mint.public.canary` |
| `mint.public.ingress.proof` |
| `mint.public.ingress.reconcile` |
| `mint.public.providers.reconcile` |
| `mint.runtime.proof` |
| `mint.seeds.query` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
