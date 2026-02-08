# Secrets (Infisical)

**Host:** `infra-core` (VM 204)  
**Live runtime path:** `/opt/stacks/secrets` (see `ops/bindings/docker.compose.targets.yaml`)

## Purpose

Self-hosted Infisical instance used as the secrets provider for spine tooling.

## Access

- Internal API: `http://100.92.91.128:8088`
- Public: `https://secrets.ronny.works` (Cloudflare tunnel -> Caddy -> Infisical)

## Secrets

This stack uses a host-local `.env` file (do not commit). Keys required are listed in `.env.example`.

Note: Because this is the secrets provider itself, treat its `.env` as a bootstrap secret surface and
avoid circular dependency on the same Infisical instance for its own credentials.

## Verification

From this repo:

```bash
./bin/ops cap run secrets.status
./bin/ops cap run services.health.status
./bin/ops cap run docker.compose.status
```

