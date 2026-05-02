# mint

Canonical domain boundary for `mint`.

**Mint product and runtime authority live in [`mint-modules`](https://github.com/hypnotizedent/mint-modules), not in spine.**
Spine retains only the governed shim/readback boundary plus compatibility paths
to Mint-owned product contracts.

- Authority: `docs/governance/SPINE.md`
- Spine domain bundle: `ops/bindings/domains/mint.bundle.yaml`
- Product/runtime contract home: `~/code/mint-modules/contracts/`
- Spine routing shims: `ops/plugins/domains/mint/bin/`
- Mint-owned product contract compatibility paths:
  - `ops/bindings/domains/mint/mint.operator.storage.contract.yaml`
  - `ops/bindings/domains/mint/mint.secrets.promotion.contract.yaml`
  - `ops/bindings/domains/mint/mint.storage.findings.map.yaml`
  - `ops/bindings/domains/mint/mint.storage.guard.policy.yaml`
  - `ops/bindings/domains/microsoft/microsoft.tenant.boring.contract.yaml`
  - `ops/bindings/domains/microsoft/microsoft.entra.admin.app.contract.yaml`
- Scoped domain health readback: `./bin/ops cap run verify.run -- domain mint`

## Registered Capabilities (5 of 5)

All 5 registered Mint capabilities delegate to `mint-modules`:
- `mint.deploy.status` — read-only Docker/container status via mint-modules shim
- `mint.live.baseline.status` — read-only live baseline status surface
- `mint.module.status.projection.build` — refresh governed status projection via mint-modules shim
- `mint.modules.health` — read-only health summary via mint-modules shim
- `mint.runtime.proof` — read-only deep runtime proof via mint-modules shim

## Boundary Status

L3 move-out is complete for Mint product/runtime authority. Spine keeps:
- 5 thin capability-routing shims in `ops/plugins/domains/mint/bin/`
- thin product authority pointers under `ops/bindings/domains/mint/`
- Microsoft tenant compatibility paths for Mint-owned contracts

Workbench `agents/mint-agent/` may retain operator tooling, but it is not the
owner of Mint runtime truth.

Runtime state under `/Users/ronnyworks/code/.runtime/spine/state/mint/` remains
external to the repo and is not part of the Mint authority move-out question.

## Order Truth

**Canonical business truth for future order-facing modules**:
- Read `ops/bindings/domains/mint/mint.order.truth.authority.yaml` (spine pointer to `mint-modules` authority)
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
