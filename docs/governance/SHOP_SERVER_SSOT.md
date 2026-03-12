---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-12
verification_method: device-identity parity + shop routing audit
scope: shop-control-plane-summary
---

# SHOP SERVER SSOT

This is the spine-facing summary for the shop rack and shop-managed endpoints.

Authority boundary:
- Canonical identity and network naming live in `docs/governance/DEVICE_IDENTITY_SSOT.md`.
- Detailed shop hardware procedures and operator runbooks live in `/Users/ronnyworks/code/workbench/docs/infrastructure/domains/shop/SHOP_SERVER_SSOT.md`.
- This spine doc keeps agent facts, ripple checks, and shop network parity attached to a real governed surface.

## Managed Shop Endpoints

| Class | Device | Canonical IP | Access Model | Notes |
|-------|--------|--------------|--------------|-------|
| Gateway | `udr-shop` | `192.168.1.1` | LAN-only | UniFi Dream Router 6 |
| Switch | `switch-shop` | `192.168.1.2` | LAN-only | Dell N2024P |
| OOB Mgmt | `idrac-shop` | `192.168.1.250` | LAN-only | Shop hypervisor iDRAC |
| Camera NVR | `nvr-shop` | `192.168.1.216` | LAN-only | Hikvision recorder |
| WiFi AP | `ap-shop` | `192.168.1.185` | LAN-only | TP-Link EAP225 |
| Hypervisor SSH | `pve` | `100.96.211.33` | Tailscale | Canonical operator SSH target |
| Tombstone VM | `docker-host` | `192.168.1.200` | Historical identity | Cold restore capsule only; not runtime |
| Automation VM | `automation-stack` | `192.168.1.110` | LAN | n8n / automation workloads |
| Photos VM | `immich` | `192.168.1.203` | LAN | Shop photos VM |
| Core infra VM | `infra-core` | `192.168.1.204` | LAN | DNS/auth/secrets core |
| Observability VM | `observability` | `192.168.1.205` | LAN | Prometheus / Grafana / Loki |
| Dev tools VM | `dev-tools` | `192.168.1.206` | LAN | Gitea and related services |
| AI VM | `ai-consolidation` | `192.168.1.8` | LAN | Qdrant / AI workloads |
| Downloads VM | `download-stack` | `192.168.1.209` | LAN | Download services |
| Streaming VM | `streaming-stack` | `192.168.1.210` | LAN | Streaming services |
| Finance VM | `finance-stack` | `192.168.1.211` | LAN | Finance services |
| Mint data VM | `mint-data` | `192.168.1.212` | LAN | Mint data plane |
| Mint apps VM | `mint-apps` | `192.168.1.213` | LAN | Mint app plane |
| Communications VM | `communications-stack` | `192.168.1.26` | LAN | Stalwart + mail archiver |

## Canonical Rack Target Model

| Plane | Canonical surface | Boring target |
|-------|-------------------|---------------|
| Substrate | `ops/bindings/hardware.inventory.yaml` | `pve` is the only shop hypervisor. |
| Storage | `ops/bindings/shop.storage.map.yaml` + `ops/bindings/hardware.inventory.yaml` + `ops/bindings/backup.inventory.yaml` | `tank` = hot runtime/app state, `media` = media payload only or phased-out pressure lane, `md1400` = cold backup/archive/staging only. |
| Runtime | `ops/bindings/vm.lifecycle.yaml` + `docs/governance/STACK_REGISTRY.yaml` | Every kept workload is a named VM/LXC or a container stack inside one; tombstones are not runtime. |
| Network | `docs/governance/DEVICE_IDENTITY_SSOT.md` + `ops/bindings/ssh.targets.yaml` | One LAN identity truth and one Tailscale truth per kept node. |
| Ingress | `ops/bindings/shop.ingress.map.yaml` + `ops/bindings/domain.routing.registry.yaml` | Public services are either intentionally published via Cloudflare or explicitly private-only, and compatibility/ghost routes are explicit. |
| Backup | `ops/bindings/backup.inventory.yaml` + `docs/governance/domains/backup.md` | One backup matrix per runtime unit: VM artifact, app/state supplement, offsite exception, and restore class. |
| Monitoring | `docs/governance/SERVICE_REGISTRY.yaml` + `ops/bindings/services.health.yaml` | Every kept VM gets a baseline of host reachability, critical service health, and capacity visibility. |
| Tombstones | `ops/bindings/docker-host.deprecation.contract.yaml` + `ops/bindings/vm.lifecycle.yaml` | Dead systems carry explicit tombstone status, one restore story, and an expiry/review date. |

## Generated Projections

- Storage authority projection: `ops/bindings/shop.storage.map.yaml`
- Ingress authority projection: `ops/bindings/shop.ingress.map.yaml`
- Rack scorecard: `docs/reference/generated/SHOP_RACK_SCORECARD.md`
- Estate closure scorecard: `docs/reference/generated/ESTATE_BORINGNESS_SCORECARD.md`
- Rebuild commands:
  - `./bin/ops cap run infra.shop.storage.authority.build`
  - `./bin/ops cap run infra.estate.boringness.build`

## Current Tombstones

| Tombstone | Runtime posture | Cold restore posture | Review date | Notes |
|-----------|-----------------|----------------------|-------------|-------|
| `docker-host` / VM200 | Not runtime. Remove `local-lvm:vm-200-disk-0` from hot storage instead of keeping a powered-off guest. | Keep exactly one cold restore capsule at `pve:/md1400/backup-cold/vzdump/pve` via `vm-200-docker-host-primary`. Restore only as isolated temporary sandbox identity. | `2026-09-06` | Historical Mint/docker-host duties are now split across `mint-apps`, `mint-data`, `finance-stack`, `observability`, and `communications-stack`. |

## Verification

```bash
./bin/ops cap run network.shop.audit.status
./bin/ops cap run spine.ripple.check -- switch-shop
./bin/ops cap run spine.ripple.check -- communications-stack
```
