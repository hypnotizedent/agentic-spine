---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-11
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
| Legacy hold VM | `docker-host` | `192.168.1.200` | LAN | Forensic/rollback hold only |
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

## Verification

```bash
./bin/ops cap run network.shop.audit.status
./bin/ops cap run spine.ripple.check -- switch-shop
./bin/ops cap run spine.ripple.check -- communications-stack
```

