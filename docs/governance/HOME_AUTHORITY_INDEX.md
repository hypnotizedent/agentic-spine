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

### Lane Separation

| Lane | Scope | Access Method | Capabilities |
|------|-------|---------------|--------------|
| Read | HA state, entities, devices, Z2M devices, areas | HA REST/WS API (bearer token) | ha.status, ha.entity.list, ha.device.map.build, ha.z2m.devices.snapshot |
| Read | UniFi devices, ports, VLANs | UniFi controller API | TBD (on-site provisioning) |
| Write | HA device rename, Z2M naming, automation edits | HA WS API + SSH to HA host | ha.device.rename, ha.z2m.device.rename |
| Write | Z2M device interview, network map | Z2M API via HA integration | TBD (on-site capability) |
| Audit | All mutations | Receipt-based via spine capabilities | Governed by cap.sh receipt system |

### Service Credential Inventory

| Service | Credential | Infisical Path | Scope | Status |
|---------|------------|----------------|-------|--------|
| Home Assistant | HA_API_TOKEN | /spine/home/HA_API_TOKEN | Long-lived access token, full API | active |
| Zigbee2MQTT | (via HA integration) | N/A | Accessed through HA, no separate credential | active |
| UniFi Controller | TBD | TBD | Controller admin credentials | pending (on-site) |

### Mutation Audit Path

All home domain mutations follow the spine capability receipt model:
1. Capability invoked via `./bin/ops cap run <capability>`
2. Receipt generated at `receipts/sessions/RCAP-<timestamp>__<capability>__<key>/`
3. Receipt includes: run key, status, output, timestamps
4. Mutation receipts committed to git for audit trail

## Execution Loop

- **Loop**: LOOP-HOME-CANONICAL-REALIGNMENT-20260302
- **Status**: planned / later / blocked (offsite)
- **Execution**: Dedicated on-site day
