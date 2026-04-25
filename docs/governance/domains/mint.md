# mint

Canonical domain policy for `mint`.

**Mint product work lives in [`mint-modules`](https://github.com/hypnotizedent/mint-modules), not in spine.**
Spine-side Mint surfaces are shared infrastructure only (SSH targets, secrets, verify, status projections).

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/mint.bundle.yaml`
- Public ingress contract: `ops/bindings/domains/mint/mint.public.ingress.contract.yaml`
- **Status authority**: `ops/bindings/domains/mint/mint.module.status.projected.yaml` (read via `mint.module.status.projection.build`)
- **Order business truth authority**: `ops/bindings/domains/mint/mint.order.truth.authority.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain mint`

## Registered Capabilities (5 of 5)

Mint status/proof capability registration is now complete for the governed read surfaces:
- `mint.deploy.status` — read-only Docker/container status via mint-modules shim
- `mint.live.baseline.status` — read-only live baseline status surface
- `mint.module.status.projection.build` — refresh governed status projection
- `mint.modules.health` — read-only health summary via mint-modules shim
- `mint.runtime.proof` — read-only deep runtime proof via mint-modules shim

## Residue Notice

Older schema (`ops/plugins/domains/mint/schema/`), runtime state (36 subdirs under
`/Users/ronnyworks/code/.runtime/spine/state/mint/`), unregistered bins (53 scripts in
`ops/plugins/domains/mint/bin/`), and lib files (1 in `ops/plugins/domains/mint/lib/`)
remain parked in spine pending a fresh aperture lift and fresh loop.
This doc does not authorize migration.

## Order Truth

**Canonical business truth for future order-facing modules**:
- Read `ops/bindings/domains/mint/mint.order.truth.authority.yaml`
- Use it for order vs quote vs revision vs artwork-binding semantics
- Do not infer business order truth from seed IDs, artwork job IDs, legacy `visual_id`, or code presence

**Current implementation rule**:
- `orders`, `quotes`, and `digital-proofs` remain blocked at the module level until they conform to the order-truth authority
- Existing seed/artwork intake stays the normalized intake boundary; it is not the order entity

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `mint.deploy.status` |
| `mint.live.baseline.status` |
| `mint.module.status.projection.build` |
| `mint.modules.health` |
| `mint.runtime.proof` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
