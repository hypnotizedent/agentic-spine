---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-stack-architecture
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: Stack Architecture

> Service topology, compose structure, and data layout for the finance stack running on finance-stack (VM 211).

## Service Graph

```
                    ┌──────────────────────────────────┐
                    │  Cloudflare Tunnel (infra-core)   │
                    │  firefly.ronny.works → :8080      │
                    │  docs.ronny.works → :8000         │
                    │  finances.ronny.works → :3333     │
                    └──────────┬───────────────────────┘
                               │
                    ┌──────────▼───────────────────────┐
                    │     finance-stack (VM 211)        │
                    │     192.168.1.211 / TS: 100.76.  │
                    ├──────────────────────────────────┤
                    │                                   │
   ┌────────┐      │  ┌──────────┐   ┌─────────────┐  │
   │ Simple │──────┼──│ Cron     │   │ Data        │  │
   │ FIN    │      │  │ (daily   │   │ Importer    │  │
   │ Bridge │      │  │  sync)   │   │ :8091       │  │
   └────────┘      │  └────┬─────┘   └──────┬──────┘  │
                   │       │                 │         │
                   │  ┌────▼─────────────────▼──────┐  │
                   │  │     Firefly III :8080        │  │
                   │  │     (PHP/Laravel)            │  │
                   │  └────────────┬────────────────┘  │
                   │               │ webhook            │
                   │               ▼                    │
                   │  ┌─────────────────┐              │
                   │  │ n8n (VM 202)    │              │
                   │  │ → Mint OS DB    │              │
                   │  └─────────────────┘              │
                   │                                   │
                   │  ┌──────────────┐  ┌───────────┐  │
                   │  │ PostgreSQL   │  │ Redis 7   │  │
                   │  │ 16           │  │ (cache)   │  │
                   │  │ (shared DB)  │  │           │  │
                   │  └──────────────┘  └───────────┘  │
                   │                                   │
                   │  ┌──────────────┐  ┌───────────┐  │
                   │  │ Paperless-ngx│  │ Ghostfolio│  │
                   │  │ :8000        │  │ :3333     │  │
                   │  └──────────────┘  └───────────┘  │
                   └──────────────────────────────────┘
```

## Docker Compose Services

| Service | Image | Port | Depends On | Restart |
|---------|-------|------|-----------|---------|
| `postgres` | postgres:16 | 5432 (internal) | — | unless-stopped |
| `redis` | redis:7 | 6379 (internal) | — | unless-stopped |
| `firefly-iii` | fireflyiii/core:latest | 8080 | postgres, redis | unless-stopped |
| `data-importer` | fireflyiii/data-importer:latest | 8091 | firefly-iii | unless-stopped |
| `cron` | alpine + curl | — | firefly-iii | unless-stopped |
| `ghostfolio` | ghostfolio/ghostfolio:latest | 3333 | postgres | unless-stopped |
| `paperless-ngx` | ghcr.io/paperless-ngx/paperless-ngx:latest | 8000 | — | unless-stopped |

**Total:** 7 containers

## Networks

| Network | Driver | Purpose |
|---------|--------|---------|
| `finance-internal` | bridge | Inter-service communication (postgres, redis, app) |
| `tunnel_network` | external | Shared with Caddy/Cloudflare tunnel for ingress |

## Data Paths (Volumes)

All persistent data is stored under `/opt/stacks/finance/data/` on finance-stack:

| Path | Service | Content |
|------|---------|---------|
| `/opt/stacks/finance/data/postgres/` | PostgreSQL | Firefly + Ghostfolio databases |
| `/opt/stacks/finance/data/redis/` | Redis | Cache data (ephemeral) |
| `/opt/stacks/finance/data/firefly-iii/upload/` | Firefly III | User-uploaded attachments |
| `/opt/stacks/finance/data/importer/` | Data Importer | Import configuration storage |
| `/opt/stacks/finance/data/paperless/data/` | Paperless-ngx | Document storage + SQLite DB |
| `/opt/stacks/finance/data/paperless/media/` | Paperless-ngx | OCR'd document files |
| `/opt/stacks/finance/data/paperless/export/` | Paperless-ngx | Document exporter output |
| `/opt/stacks/finance/data/ghostfolio/` | Ghostfolio | Application data |

## Environment Variables (Key Configuration)

### Firefly III

| Variable | Purpose | Source |
|----------|---------|--------|
| `APP_KEY` | Laravel encryption key (32 chars) | Infisical |
| `DB_HOST` / `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` | PostgreSQL connection | Infisical + compose |
| `TRUSTED_PROXIES` | Set to `**` for Cloudflare tunnel | .env |
| `APP_URL` | `https://firefly.ronny.works` | .env |
| `FIREFLY_III_ACCESS_TOKEN` | PAT for API access | Infisical |

### Data Importer

| Variable | Purpose | Source |
|----------|---------|--------|
| `FIREFLY_III_URL` | API base URL | .env |
| `FIREFLY_III_ACCESS_TOKEN` | Same PAT as Firefly | Infisical |
| `NORDIGEN_ID` / `NORDIGEN_KEY` | Deprecated (was EU bank sync) | N/A |

### Paperless-ngx

| Variable | Purpose | Source |
|----------|---------|--------|
| `PAPERLESS_SECRET_KEY` | Django secret | Infisical |
| `PAPERLESS_URL` | `https://docs.ronny.works` | .env |
| `PAPERLESS_OCR_LANGUAGE` | `eng` | .env |
| `PAPERLESS_CONSUMER_POLLING` | Watch interval for new docs | .env |

### Ghostfolio

| Variable | Purpose | Source |
|----------|---------|--------|
| `DATABASE_URL` | PostgreSQL connection string | .env |
| `ACCESS_TOKEN_SALT` | Auth token salt | Infisical |
| `JWT_SECRET_KEY` | JWT signing key | Infisical |

## Compose File Location

- **On finance-stack:** `/opt/stacks/finance/docker-compose.yml`
- **Spine binding:** `docker.compose.targets.yaml` → `/opt/stacks/finance` (registered as stub)

## Port Summary

| Port | Service | Exposure |
|------|---------|----------|
| 8080 | Firefly III | Cloudflare tunnel → `firefly.ronny.works` |
| 8091 | Data Importer | Local only (manual import UI) |
| 8000 | Paperless-ngx | Cloudflare tunnel → `docs.ronny.works` |
| 3333 | Ghostfolio | Cloudflare tunnel → `finances.ronny.works` |
| 5432 | PostgreSQL | Internal only (finance-internal network) |
| 6379 | Redis | Internal only (finance-internal network) |

## Dedicated VM (finance-stack VM 211)

Finance runs on its own dedicated VM (VM 211). It was migrated from the legacy docker-host (VM 200) around 2026-02-11.

- **Mint OS** remains on docker-host (VM 200) — separate VM, separate lifecycle.
- **Mail-Archiver** also remains on docker-host (VM 200).

## Known Architectural Debt

| Issue | Impact | Notes |
|-------|--------|-------|
| ~~Shared VM with Mint OS~~ | Resolved | Finance migrated to dedicated VM 211 |
| PostgreSQL shared across services | Single DB failure affects Firefly + Ghostfolio | Consider separate instances |
| No health check probes in compose | Docker can't auto-restart unhealthy services | Add `healthcheck:` to compose |
| Ghostfolio unconfigured | No investment data loaded | P3 priority |
| No Prometheus/Grafana metrics | No observability | Future work |
