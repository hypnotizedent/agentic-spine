---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: ingress-routing
---

# Ingress Authority

Purpose: document the routing layer between DNS and services (Cloudflare Tunnel, connector runtime, and the infra-core reverse proxy).

## TL;DR (Authority)

| Layer | Runtime Authority | Docs / SSOT |
|------|-------------------|-------------|
| DNS | Cloudflare Dashboard | `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` (docs-only SSOT) |
| Tunnel ingress (hostname -> service) | Cloudflare Zero Trust Dashboard | Export via `cloudflare.tunnel.ingress.status`; diff via `cloudflare.domain_routing.diff` |
| Tunnel connector container (cloudflared) | `infra-core` host runtime | Canonical compose: `ops/staged/cloudflared/docker-compose.yml` |
| Reverse proxy on infra-core (Caddy) | `infra-core` host runtime | Canonical compose: `ops/staged/caddy-auth/docker-compose.yml` |
| Live host stack paths | `ops/bindings/docker.compose.targets.yaml` | Binding SSOT (never guess `/opt/stacks` vs `~/stacks`) |
| Health probes | `ops/bindings/services.health.yaml` | Binding SSOT (read-only HTTP probes) |

Key fact: tunnel ingress rules are **dashboard-managed**. The repo contains the connector container config, but NOT the hostname -> service routing rules.

## Architecture Overview

```
Cloudflare (DNS + Tunnel Public Hostnames)  [dashboard-managed]
                 |
                 v
        Tunnel: homelab-tunnel
                 |
                 v
   infra-core (VM 204) runs cloudflared connector
                 |
                 +--> routes some hostnames to Caddy on infra-core (127.0.0.1:80)
                 |      - auth.ronny.works   -> Authentik (:9000)
                 |      - pihole.ronny.works -> Pi-hole (:8053)
                 |      - secrets.ronny.works-> Infisical (:8088)
                 |      - vault.ronny.works  -> Vaultwarden (:8081)
                 |
                 +--> routes other hostnames directly to services on other hosts
                        (by Tailscale IP, or by docker DNS names mapped via extra_hosts)
```

## Exporting Truth (No Dashboard Guessing)

### Export tunnel ingress (hostname -> service)

```bash
./bin/ops cap run cloudflare.tunnel.ingress.status
```

### Diff tunnel ingress vs DOMAIN_ROUTING_REGISTRY

This is audit/gate-friendly (exits non-zero on diffs):

```bash
./bin/ops cap run cloudflare.domain_routing.diff
```

## Updating Docs (Docs-only)

When tunnel ingress changes in the dashboard:

1. Update `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` (set `routing_layer: cloudflare_tunnel` for active hostnames).
2. Keep `authority_source` accurate (`cloudflare_dashboard` for ingress edits).
3. Re-run `cloudflare.domain_routing.diff` until it reports no diffs.

## Related SSOTs

- Domain routing: `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml`
- SSH host inventory: `ops/bindings/ssh.targets.yaml`
- Live compose directories: `ops/bindings/docker.compose.targets.yaml`
- Health probes: `ops/bindings/services.health.yaml`

