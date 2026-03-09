# mint

Canonical domain policy for `mint`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/mint.bundle.yaml`
- Public ingress contract: `ops/bindings/mint.public.ingress.contract.yaml`
- **Status authority**: `ops/bindings/mint.module.status.projected.yaml` (read via `mint.module.status.show`)
- Verify entrypoint: `./bin/ops cap run verify.run -- domain mint`
- Public deploy closeout: `mint.modules.health` -> `mint.runtime.proof` -> `mint.public.ingress.proof` -> `mint.quote.edge.reconcile` -> `mint.public.canary`

## Status Consumption

**Default status read**: `./bin/ops cap run mint.module.status.show`
- Fast, read-only
- Consumes governed projection at `ops/bindings/mint.module.status.projected.yaml`
- Does NOT re-run expensive proof by default

**Advanced status checks**:
- Explicit baseline: `mint.live.baseline.status`
- Deep runtime proof: `mint.runtime.proof`
- Refresh projection: `mint.module.status.projection.build`

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
| `mint.module.status.projection.build` |
| `mint.module.status.show` |
| `mint.modules.health` |
| `mint.quote.edge.reconcile` |
| `mint.quote.turnstile.reconcile` |
| `mint.public.canary` |
| `mint.public.ingress.proof` |
| `mint.public.ingress.reconcile` |
| `mint.public.providers.reconcile` |
| `mint.runtime.proof` |
| `mint.seeds.query` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
