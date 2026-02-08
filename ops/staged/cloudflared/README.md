# cloudflared (Cloudflare Tunnel Connector)

**Host:** `infra-core` (VM 204)  
**Live runtime path:** `/opt/stacks/cloudflared` (see `ops/bindings/docker.compose.targets.yaml`)

## Purpose

Runs the Cloudflare Tunnel connector for tunnel `homelab-tunnel`.

Important: ingress rules (hostname -> service) are **dashboard-managed**, not repo-managed.
See `docs/governance/INGRESS_AUTHORITY.md`.

## Secrets

Populate `.env` on the host (do not commit). Keys required are listed in `.env.example`.

- `CLOUDFLARE_TUNNEL_TOKEN`
  - Infisical path: `/spine/network/edge`

## Verification

From this repo:

```bash
./bin/ops cap run cloudflare.tunnel.status
./bin/ops cap run cloudflare.tunnel.ingress.status
./bin/ops cap run cloudflare.domain_routing.diff
./bin/ops cap run docker.compose.status
```

