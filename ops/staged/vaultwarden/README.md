# Vaultwarden

**Host:** `infra-core` (VM 204)  
**Live runtime path:** `/opt/stacks/vaultwarden` (see `ops/bindings/docker.compose.targets.yaml`)

## Purpose

Password vault (Vaultwarden) for human-managed secrets and bootstrap credentials.

## Access

- Internal liveness: `http://100.92.91.128:8081/alive`
- Public: `https://vault.ronny.works` (Cloudflare tunnel -> Caddy -> Vaultwarden)

## Secrets

Sensitive secrets are stored in Infisical at `/spine/vm-infra/vaultwarden/`:
- `VAULTWARDEN_ADMIN_TOKEN` — admin panel access token
- `VAULTWARDEN_ADMIN_TOKEN_PLAINTEXT` — optional plaintext admin token for API/admin automation
- `VAULTWARDEN_BW_SERVER_URL` — Vaultwarden base URL for `bw` CLI
- `VAULTWARDEN_BW_CLIENTID` — Vaultwarden API key client ID for `bw` CLI
- `VAULTWARDEN_BW_CLIENTSECRET` — Vaultwarden API key client secret for `bw` CLI
- `VAULTWARDEN_BW_MASTER_PASSWORD` — Vaultwarden account master password for `bw unlock`

Non-secret configuration lives in the host-local `.env` file (do not commit).
Keys required are listed in `.env.example` (DOMAIN, LOG_LEVEL, TZ, etc.).

## Backup + Restore

See [`docs/governance/VAULTWARDEN_BACKUP_RESTORE.md`](../../../docs/governance/VAULTWARDEN_BACKUP_RESTORE.md).

## Verification

From this repo:

```bash
./bin/ops cap run services.health.status
./bin/ops cap run docker.compose.status
```
