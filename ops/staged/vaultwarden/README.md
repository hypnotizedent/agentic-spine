# Vaultwarden

**Host:** `infra-core` (VM 204)  
**Live runtime path:** `/opt/stacks/vaultwarden` (see `ops/bindings/docker.compose.targets.yaml`)

## Purpose

Password vault (Vaultwarden) for human-managed secrets and bootstrap credentials.

## Access

- Internal liveness: `http://100.92.91.128:8081/alive`
- Public: `https://vault.ronny.works` (Cloudflare tunnel -> Caddy -> Vaultwarden)

## Secrets

This stack uses a host-local `.env` file (do not commit). Keys required are listed in `.env.example`.

Common keys:
- `ADMIN_TOKEN`
- `DOMAIN`

## Verification

From this repo:

```bash
./bin/ops cap run services.health.status
./bin/ops cap run docker.compose.status
```

