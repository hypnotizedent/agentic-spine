# Caddy + Authentik Preflight Checklist

| Field | Value |
|-------|-------|
| Generated | `2026-02-07T20:17:00Z` |
| Loop | `LOOP-INFRA-CADDY-AUTH-20260207` |
| Blocker | `LOOP-INFRA-VM-RESTRUCTURE-20260206` promotion gate |
| Earliest execute window | `2026-02-08T04:41:00Z` |

## Staged Artifacts

```
ops/staged/caddy-auth/
├── docker-compose.yml
├── Caddyfile
└── .env.example
```

## Readiness Checks

| Check | Status | Notes |
|------|--------|-------|
| Caddy/Auth stack draft staged | PASS | Compose + Caddyfile ready |
| Uses canonical staging location | PASS | `ops/staged/caddy-auth/` |
| Authentik secret key in Infisical | FAIL | `AUTHENTIK_SECRET_KEY` missing |
| Authentik DB password in Infisical | FAIL | `AUTHENTIK_DB_PASSWORD` missing |

## Required Secret Actions (Before Execute)

1. Create `AUTHENTIK_SECRET_KEY` in Infisical (`infrastructure`, `prod`).
2. Create `AUTHENTIK_DB_PASSWORD` in Infisical (`infrastructure`, `prod`).
3. Render `.env` from Infisical at deploy time on infra-core.

## Deploy Sequence (Post-Promotion)

1. Copy staged files to infra-core:
   `scp -r ops/staged/caddy-auth/* ubuntu@infra-core:/opt/stacks/caddy-auth/`
2. Render `/opt/stacks/caddy-auth/.env` with Infisical-backed values.
3. Start stack:
   `ssh ubuntu@infra-core 'cd /opt/stacks/caddy-auth && sudo docker compose up -d'`
4. Validate:
   - `curl -fsS -o /dev/null -w "%{http_code}" http://100.92.91.128:9000/` (expect `200/302`)
   - `curl -fsS -o /dev/null -w "%{http_code}" https://auth.ronny.works` (expect `200/302`)

## Gate Note

Do not execute deployment until vaultwarden promotion gate clears and service state is recorded as migrated.
