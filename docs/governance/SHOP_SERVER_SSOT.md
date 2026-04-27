---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-27
verification_method: device-identity parity + shop routing audit
scope: shop-control-plane-summary
---

# SHOP SERVER SSOT

This is the spine-facing summary for the shop rack and shop-managed endpoints.

## Authority Sources

| Plane | Canonical Surface |
|-------|-------------------|
| Substrate | `ops/bindings/hardware.inventory.yaml` |
| Storage | `ops/bindings/shop.storage.map.yaml` + `ops/bindings/shop.media.pressure.authority.yaml` |
| Runtime | `ops/bindings/vm.lifecycle.yaml` + `docs/governance/STACK_REGISTRY.yaml` |
| Network | `docs/governance/DEVICE_IDENTITY_SSOT.md` + `ops/bindings/ssh.targets.yaml` |
| Ingress | `ops/bindings/shop.ingress.map.yaml` + `ops/bindings/domain.routing.registry.yaml` |
| Backup | `ops/bindings/domains/backup/backup.inventory.yaml` |
| Monitoring | `docs/governance/SERVICE_REGISTRY.yaml` + `ops/bindings/services.health.yaml` |
| Tombstones | `ops/bindings/vm.lifecycle.yaml` (status: decommissioned) |

## Generated Read Model

The factual endpoint/VM/hardware tables that were formerly maintained here are now
generated from the structured bindings above:

```bash
./bin/ops cap run infra.shop.readmodel.generate
```

Output: `.runtime/spine/state/domain-state/infra.shop.readmodel.md` (runtime only, not committed)

## Generated Projections

- Storage authority projection: `ops/bindings/shop.storage.map.yaml`
- Warm-lane pressure authority: `ops/bindings/shop.media.pressure.authority.yaml`
- Ingress authority projection: `ops/bindings/shop.ingress.map.yaml`
- Rack scorecard: `docs/reference/generated/SHOP_RACK_SCORECARD.md`
- Estate closure scorecard: `docs/reference/generated/ESTATE_BORINGNESS_SCORECARD.md`
- Rebuild commands:
  - `./bin/ops cap run infra.shop.storage.authority.build`
  - `./bin/ops cap run media.capacity.snapshot.build`
  - `./bin/ops cap run infra.estate.boringness.build`

## Verification

```bash
./bin/ops cap run network.shop.audit.status
./bin/ops cap run spine.ripple.check -- switch-shop
./bin/ops cap run spine.ripple.check -- communications-stack
```

## Detail

Detailed shop hardware procedures and operator runbooks live in:
`~/code/workbench/docs/infrastructure/domains/shop/SHOP_SERVER_SSOT.md`
