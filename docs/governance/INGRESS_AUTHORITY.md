---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: ingress-routing
---

# Ingress Authority

> **Purpose**: Document the routing layer between DNS and stacks — the "middle bridge" that connects hostnames to services.

---

## TL;DR

| Layer | SSOT Location | Managed By |
|-------|---------------|------------|
| **DNS** | `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` | Cloudflare Dashboard |
| **Ingress/Routing** | Cloudflare Dashboard (Zero Trust → Tunnels) | **Dashboard** (not repo) |
| **Stacks** | `docs/governance/STACK_REGISTRY.yaml` | Repo |

**Key fact**: Tunnel ingress rules are **dashboard-managed**. The repo contains the tunnel container config, but NOT the hostname → service routing rules.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARE                                   │
│  ┌──────────────┐    ┌──────────────────────────────────────────┐  │
│  │   DNS Zone   │───▶│  Zero Trust → Tunnels → Public Hostnames │  │
│  │  (Dashboard) │    │              (Dashboard)                  │  │
│  └──────────────┘    └──────────────────────────────────────────┘  │
│                                      │                               │
│                                      ▼                               │
│                        ┌─────────────────────────┐                  │
│                        │ Tunnel: homelab-tunnel  │                  │
│                        │ Token: TUNNEL_TOKEN     │                  │
│                        └─────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       DOCKER-HOST (100.92.156.118)                   │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ cloudflared container (homelab-cloudflared)                   │  │
│  │ Compose: infrastructure/cloudflare/tunnel/docker-compose.yml │  │
│  │ Networks: tunnel_network, mint-os-network                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Target services (reached by Docker DNS or localhost:port)    │  │
│  │ Examples: dashboard-api:3335, admin:3333, minio:9000         │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tunnel Configuration

### Repo-Managed (Container Only)

| File | Purpose |
|------|---------|
| `infrastructure/cloudflare/tunnel/docker-compose.yml` | Tunnel container definition |

The compose file runs `cloudflared` with:
- `command: tunnel --no-autoupdate run`
- `TUNNEL_TOKEN` from environment

This is a **token-based tunnel** — the tunnel fetches its configuration (including ingress rules) from Cloudflare's API at runtime.

### Dashboard-Managed (Ingress Rules)

Ingress rules are configured in:
```
Cloudflare Dashboard → Zero Trust → Networks → Tunnels → homelab-tunnel → Public Hostnames
```

**To view current ingress rules:**
1. Log in to Cloudflare Dashboard
2. Navigate: Zero Trust → Networks → Tunnels
3. Select tunnel: `homelab-tunnel`
4. View "Public Hostnames" tab

**To export (read-only, for documentation):**
```bash
# Requires CF API token with tunnel:read scope
# Not currently automated — manual export recommended
```

---

## Zone: ronny.works

### Known Tunnel Routes

| Hostname | Target Service | Port | Stack Path |
|----------|----------------|------|------------|
| `secrets.ronny.works` | secrets | — | `infrastructure/secrets/` |
| `files.ronny.works` | files-api | 3500 | `modules/files-api/` |
| `mintprints-api.ronny.works` | dashboard-api | 3335 | `infrastructure/docker-host/mint-os/` |

### Hostnames with Unknown Routing

These are in DNS but routing authority is not confirmed:

| Hostname | Likely Target | Status |
|----------|---------------|--------|
| `ronny.works` | TBD | Unknown |
| `www.ronny.works` | TBD | Unknown |
| `chat.ronny.works` | TBD | Unknown |
| `dash.ronny.works` | dashy:4000 | Likely tunnel |
| `docs.ronny.works` | TBD | Unknown |
| `finances.ronny.works` | firefly:8080 | Likely tunnel |
| `grafana.ronny.works` | grafana:3000 | Likely tunnel |
| `ha.ronny.works` | home-assistant | Likely tunnel |
| `investments.ronny.works` | ghostfolio | Likely tunnel |
| `jellyfin.ronny.works` | jellyfin:8096 | Likely tunnel |
| `minio.ronny.works` | minio:9001 | Likely tunnel |
| `mintprints-app.ronny.works` | customer:3334 | Likely tunnel |
| `n8n.ronny.works` | n8n:5678 | Likely tunnel |
| `photos.ronny.works` | immich | Likely tunnel |
| `requests.ronny.works` | overseerr:5055 | Likely tunnel |
| `vault.ronny.works` | vaultwarden | Likely tunnel |

---

## Zone: mintprints.co

### Known Tunnel Routes

| Hostname | Target Service | Port | Stack Path |
|----------|----------------|------|------------|
| `admin.mintprints.co` | admin | 3333 | `infrastructure/docker-host/mint-os/` |
| `api.mintprints.co` | dashboard-api | 3335 | `infrastructure/docker-host/mint-os/` |
| `customer.mintprints.co` | customer | 3334 | `infrastructure/docker-host/mint-os/` |
| `production.mintprints.co` | production | 3336 | `infrastructure/docker-host/mint-os/` |
| `files.mintprints.co` | files-api | 3500 | `modules/files-api/` |

### Hostnames with Unknown Routing

| Hostname | Likely Target | Status |
|----------|---------------|--------|
| `mintprints.co` | TBD | Unknown |
| `www.mintprints.co` | TBD | Unknown |
| `artwork.mintprints.co` | TBD | Unknown |
| `shipping.mintprints.co` | TBD | Unknown |
| `suppliers.mintprints.co` | TBD | Unknown |
| `estimator.mintprints.co` | TBD | Unknown |
| `kanban.mintprints.co` | TBD | Unknown |
| `mcp.mintprints.co` | TBD | Unknown |
| `minio.mintprints.co` | minio:9001 | Likely tunnel |
| `pricing.mintprints.co` | TBD | Unknown |
| `send.mintprints.co` | TBD | Unknown |
| `stock-dst.mintprints.co` | TBD | Unknown |

### DNS-Only Records (No Tunnel)

| Hostname | Type | Purpose |
|----------|------|---------|
| `_dmarc.mintprints.co` | TXT | DMARC policy |
| `resend._domainkey.mintprints.co` | TXT | DKIM for Resend |

---

## Service Port Reference

Quick reference for common service ports (from compose files):

| Service | Port | Compose File |
|---------|------|--------------|
| dashboard-api | 3335 | `infrastructure/docker-host/mint-os/docker-compose.yml` |
| admin | 3333 | `infrastructure/docker-host/mint-os/docker-compose.yml` |
| customer | 3334 | `infrastructure/docker-host/mint-os/docker-compose.yml` |
| production | 3336 | `infrastructure/docker-host/mint-os/docker-compose.yml` |
| files-api | 3500 | `modules/files-api/docker-compose.yml` |
| minio (API) | 9000 | `infrastructure/storage/docker-compose.yml` |
| minio (Console) | 9001 | `infrastructure/storage/docker-compose.yml` |
| n8n | 5678 | `infrastructure/n8n/docker-compose.yml` |
| dashy | 4000 | `infrastructure/dashy/docker-compose.yml` |
| jellyfin | 8096 | `media-stack/docker-compose.yml` |
| overseerr | 5055 | `media-stack/docker-compose.yml` |
| grafana | 3000 | `infrastructure/docker-host/mint-os/docker-compose.monitoring.yml` |
| prometheus | 9090 | `infrastructure/docker-host/mint-os/docker-compose.monitoring.yml` |

---

## Other Ingress Mechanisms

### No Reverse Proxy in Repo

The repo does not contain nginx/traefik/caddy reverse proxy configurations. All external traffic routes through Cloudflare Tunnel.

### Direct Access (Internal)

Some services are accessed directly via Tailscale without tunnel:
- Prometheus metrics endpoints
- Internal monitoring
- SSH access

---

## Operational Notes

### Adding a New Public Hostname

1. **Add DNS record** in Cloudflare Dashboard (zone settings)
2. **Add tunnel ingress rule** in Zero Trust → Tunnels → homelab-tunnel → Public Hostnames
3. **Update DOMAIN_ROUTING_REGISTRY.yaml** with routing_layer and target
4. **Update this document** with the new hostname

### Verifying Routing

```bash
# Check if hostname resolves to tunnel
dig +short <hostname>

# Verify tunnel container is running
docker ps | grep cloudflared

# Check tunnel logs
docker logs homelab-cloudflared --tail 50
```

---

## Known Gaps / TODOs

- [ ] Export tunnel ingress rules from dashboard for documentation
- [ ] Confirm "likely tunnel" hostnames in tables above
- [ ] Document any hostnames that bypass tunnel (direct to origin)
- [ ] Add automation to detect tunnel config drift

### Why TBD Entries Exist

The "Hostnames with Unknown Routing" tables above contain entries marked TBD.
These are DNS records confirmed present in Cloudflare zone exports but whose
routing path (tunnel vs direct vs inactive) has not been verified against the
live dashboard.

**Verification commands:**

```bash
# Check if a hostname resolves through the tunnel (CNAME to cfargotunnel.com)
dig +short CNAME <hostname>

# List tunnel public hostnames (requires CF API token with tunnel:read)
# Not yet automated — manual dashboard check recommended

# Verify domain routing registry completeness
yq eval '.zones[].hostnames[] | select(.stack == "TBD") | .hostname' \
  docs/governance/DOMAIN_ROUTING_REGISTRY.yaml
```

**Categories of TBD entries:**

| Category | Count | Reason |
|----------|-------|--------|
| Apex/www domains | 4 | No service deployed; DNS reserved |
| Inactive domains | 8 | DNS record exists but service not deployed |
| Pending services | 10 | Service planned, compose stack not created yet |
| DNS-only records | 2 | DKIM/DMARC policy records, no routing target |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [Governance Index](GOVERNANCE_INDEX.md) | Entry point for all governance docs |
| [DOMAIN_ROUTING_REGISTRY.yaml](./DOMAIN_ROUTING_REGISTRY.yaml) | Hostname → routing layer SSOT |
| [STACK_REGISTRY.yaml](./STACK_REGISTRY.yaml) | Stack locations SSOT |
| [SERVICE_REGISTRY.yaml](SERVICE_REGISTRY.yaml) | What runs where |
| [CI_RUNNER_REQUIREMENTS.md](./CI_RUNNER_REQUIREMENTS.md) | Deploy runner contract |
