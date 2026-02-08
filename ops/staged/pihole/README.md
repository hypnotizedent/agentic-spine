# Pi-hole (DNS)

**Host:** `infra-core` (VM 204)  
**Live runtime path:** `/opt/stacks/pihole` (see `ops/bindings/docker.compose.targets.yaml`)

## Purpose

Network DNS filtering (Pi-hole), relocated to infra-core.

## Access

- Internal admin UI: `http://100.92.91.128:8053/admin/`
- Public admin surface: `https://pihole.ronny.works` (Cloudflare tunnel -> Caddy -> Pi-hole)

## Secrets

Populate `.env` on the host (do not commit). Keys required are listed in `.env.example`.

- `PIHOLE_PASSWORD` (web UI password)

## Verification

From this repo:

```bash
./bin/ops cap run services.health.status
./bin/ops cap run docker.compose.status
```

