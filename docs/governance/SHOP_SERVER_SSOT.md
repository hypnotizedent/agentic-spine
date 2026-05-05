---
status: authoritative
owner: "@ronny"
last_verified: 2026-05-05
verification_method: first-class site presence, node admission, and shop DHCP readback
scope: shop-control-plane-summary
---

# SHOP SERVER SSOT

This is the spine-facing summary for the shop rack and shop-managed endpoints.

## Authority Sources

| Plane | Canonical Surface |
|-------|-------------------|
| Substrate | `ops/bindings/hardware.inventory.yaml` |
| Storage/Payload Custody | `payload.custody.status` |
| Runtime | `ops/bindings/vm.lifecycle.yaml` + `docs/governance/STACK_REGISTRY.yaml` |
| Network | `ops/bindings/ssh.targets.yaml` + `docs/governance/DEVICE_IDENTITY_SSOT.md` naming/topology conventions |
| Ingress | `ops/bindings/shop.ingress.map.yaml` + `ops/bindings/domain.routing.registry.yaml` |
| Backup | `ops/bindings/domains/backup/backup.inventory.yaml` |
| Monitoring | `ops/bindings/probe.registry.yaml` + `ops/bindings/services.health.yaml` |
| Tombstones | `ops/bindings/vm.lifecycle.yaml` (status: decommissioned) |

## First-Class Readbacks

The old shop summary read model has been retired. Current shop/site truth is read
through the canonical surfaces listed below, not a generated shop adapter.

## Generated Projections

- Payload/storage custody readback: `payload.custody.status`
- Storage compatibility projection: `ops/bindings/shop.storage.map.yaml`
- Warm-lane pressure compatibility evidence: `ops/bindings/shop.media.pressure.authority.yaml`
- Ingress authority projection: `ops/bindings/shop.ingress.map.yaml`
- Rack scorecard: `docs/reference/generated/SHOP_RACK_SCORECARD.md`
- Estate closure scorecard: `docs/reference/generated/ESTATE_BORINGNESS_SCORECARD.md`
- Rebuild commands:
  - `./bin/ops cap run infra.shop.storage.authority.build`
  - `./bin/ops cap run media.capacity.snapshot.build`
  - `./bin/ops cap run infra.estate.boringness.build`

## Verification

```bash
./bin/ops cap run site.presence.status
./bin/ops cap run node.admission.status
./bin/ops cap run network.shop.dhcp.audit
./bin/ops cap run spine.ripple.check -- switch-shop
./bin/ops cap run spine.ripple.check -- communications-stack
```

## Detail

Detailed shop hardware procedures and operator runbooks live in:
`~/code/workbench/docs/infrastructure/domains/shop/SHOP_SERVER_SSOT.md`
