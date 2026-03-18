# mint

Canonical domain policy for `mint`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/mint.bundle.yaml`
- Public ingress contract: `ops/bindings/mint.public.ingress.contract.yaml`
- Fleet identity contract: `ops/bindings/mint.fleet.identity.contract.yaml`
- Agents 2.0 execution model: `docs/reference/mint/MINT_AGENTS_2_0_EXECUTION_MODEL_20260313.md`
- Morpheus outbound reply policy: `ops/bindings/mint.customer.reply.draft.policy.contract.yaml`
- Customer identity contract: `ops/bindings/mint.customer.identity.contract.yaml`
- **Status authority**: `ops/bindings/mint.module.status.projected.yaml` (read via `mint.module.status.show`)
- **Order business truth authority**: `ops/bindings/mint.order.truth.authority.yaml`
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

## Order Truth

**Canonical business truth for future order-facing modules**:
- Read `ops/bindings/mint.order.truth.authority.yaml`
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
| `mint.customer.inbox.triage` |
| `mint.customer.forwarded.attachment.resolve` |
| `mint.customer.artwork.revision.prepare` |
| `mint.customer.identity.set` |
| `mint.customer.reply.draft` |
| `mint.customer.thread.delta.capture` |
| `mint.artwork.place` |
| `mint.deploy.status` |
| `mint.deploy.sync` |
| `mint.intake.validate` |
| `mint.live.baseline.status` |
| `mint.loop.daily` |
| `mint.migrate.dryrun` |
| `mint.module.status.projection.build` |
| `mint.modules.health` |
| `mint.runtime.proof` |
| `mint.seeds.query` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
