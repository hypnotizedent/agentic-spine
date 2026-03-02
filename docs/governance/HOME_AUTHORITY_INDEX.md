# Home Domain Authority Index

> Canonical index for the Home infrastructure domain.
> Authority: LOOP-HOME-CANONICAL-REALIGNMENT-20260302
> Status: skeleton (pending on-site population)

## Domain Boundary

The Home domain covers all infrastructure at the home location:
- Home Assistant (HA) instance and all managed devices
- Zigbee/Thread mesh network (Z2M + SLZB-06MU coordinator)
- UniFi network equipment (router, switches, APs)
- Proxmox-home node (if applicable)
- All IoT devices, automations, dashboards, and integrations

## Authority Contracts

| Contract | Path | Status |
|----------|------|--------|
| Home Authority Contract | `ops/bindings/home.authority.contract.yaml` | skeleton |
| Hardware Inventory | `ops/bindings/home.hardware.inventory.yaml` | skeleton |
| UniFi Network Inventory | `ops/bindings/home.unifi.network.inventory.yaml` | skeleton |
| Proxmox Inventory | `ops/bindings/home.proxmox.inventory.yaml` | skeleton |
| HA Catalog Snapshot | `ops/bindings/home.assistant.catalog.snapshot.yaml` | skeleton |
| Automation Registry | `ops/bindings/home.automation.registry.yaml` | skeleton |
| Dashboard Registry | `ops/bindings/home.dashboard.registry.yaml` | skeleton |

## Related Existing Files

| File | Purpose |
|------|---------|
| `docs/governance/DEVICE_IDENTITY_SSOT.md` | Cross-site device identity (includes home devices) |
| `ops/bindings/ha.ssot.baseline.yaml` | HA entity baseline snapshot |
| `ops/bindings/z2m.devices.yaml` | Z2M device registry |
| `ops/bindings/z2m.naming.yaml` | Z2M canonical naming |
| `ops/bindings/ha.device.map.yaml` | HA device cross-reference map |
| `ops/bindings/ha.areas.yaml` | HA area registry |

## Verify Ring Assignment

Home gates must be separated from spine-core fast verify ring:

| Gate | Description | Ring Target |
|------|-------------|-------------|
| D113 | Coordinator health probe | home-runtime |
| D114 | HA automation stability | home-runtime |
| D115 | HA SSOT baseline freshness | home-runtime |
| D118 | Z2M device health | home-runtime |
| D119 | Z2M naming parity | home-runtime |
| D120 | HA area parity | home-runtime |

## Access Model

| Lane | Scope | Credentials |
|------|-------|-------------|
| Read | HA API, Z2M API, UniFi controller | HA_API_TOKEN, Z2M via HA |
| Write | HA config, Z2M naming, device management | Same + SSH to HA host |
| Audit | All mutations logged | Receipt-based via spine capabilities |

## Execution Loop

- **Loop**: LOOP-HOME-CANONICAL-REALIGNMENT-20260302
- **Status**: planned / later / blocked (offsite)
- **Execution**: Dedicated on-site day
