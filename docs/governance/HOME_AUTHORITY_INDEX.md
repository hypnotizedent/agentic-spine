# Home Domain Authority Index

> Canonical index for the Home infrastructure domain.
> Authority: LOOP-HOME-CANONICAL-REALIGNMENT-20260302
> Status: active

## Domain Boundary

The Home domain covers all infrastructure at the home location:
- Home Assistant runtime + managed entities/devices
- Zigbee/Thread/Z-Wave coordinator surfaces
- UniFi gateway/switch topology and WLAN/network inventory
- Proxmox-home compute runtime
- Home hardware core inventory

## Authority Contracts

| Contract | Path | Status |
|----------|------|--------|
| Home Authority Contract | `ops/bindings/home.authority.contract.yaml` | authoritative |
| Hardware Inventory | `ops/bindings/home.hardware.inventory.yaml` | authoritative |
| UniFi Network Inventory | `ops/bindings/home.unifi.network.inventory.yaml` | authoritative |
| Proxmox Inventory | `ops/bindings/home.proxmox.inventory.yaml` | authoritative |
| Zigbee Reliability Baseline | `ops/bindings/home.zigbee.reliability.baseline.yaml` | authoritative |
| HA Catalog Snapshot | `ops/bindings/home.assistant.catalog.snapshot.yaml` | authoritative |
| Automation Registry | `ops/bindings/home.automation.registry.yaml` | authoritative |
| Dashboard Registry | `ops/bindings/home.dashboard.registry.yaml` | authoritative |

## Verify Ring Assignment

Home runtime gates are isolated from spine-core fast verify ring:

| Gate | Description | Ring Target |
|------|-------------|-------------|
| D113 | Coordinator health probe | home-runtime |
| D114 | HA automation stability | home-runtime |
| D115 | HA SSOT baseline freshness | home-runtime |
| D118 | Z2M device health | home-runtime |
| D119 | Z2M naming parity | home-runtime |
| D120 | HA area parity | home-runtime |

## Access Model

| Lane | Scope | Access Method | Capabilities |
|------|-------|---------------|--------------|
| Read | HA state/entities/devices | HA API token | `ha.status`, `ha.entity.state.baseline`, `ha.ssot.baseline.build` |
| Read | UniFi networks/clients | UDR API via proxmox-home relay | `network.home.unifi.clients.snapshot` |
| Read | Proxmox-home VM/LXC runtime | SSH over Tailscale | `home.vm.status`, `home.health.check` |
| Read | Zigbee reliability baseline | HA + Z2M runtime snapshots | `ha.z2m.health`, `ha.z2m.devices.snapshot` |
| Write | Home mutations | Governed `cap` mutation surfaces | Receipts under `receipts/sessions/` |

## Execution Loop

- Loop: `LOOP-HOME-CANONICAL-REALIGNMENT-20260302`
- Current state: active
- Last authority refresh: `2026-03-04`
