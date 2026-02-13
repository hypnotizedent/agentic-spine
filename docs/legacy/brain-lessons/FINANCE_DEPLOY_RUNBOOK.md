---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-deploy-runbook
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: Deployment Runbook

> Step-by-step deployment and configuration procedures for the finance stack on finance-stack (VM 211).

## Pre-Flight Checklist

Before deploying or redeploying:

- [ ] SSH access to finance-stack confirmed (`ssh ubuntu@192.168.1.211`)
- [ ] Docker and docker-compose-plugin installed
- [ ] Data directories available under `/opt/stacks/finance/`
- [ ] Infisical CLI installed and authenticated
- [ ] Cloudflare tunnel running (via infra-core)
- [ ] DNS records exist: `firefly.ronny.works`, `docs.ronny.works`, `finances.ronny.works`

## Phase 1: Directory Setup

```bash
# Create stack directory
sudo mkdir -p /opt/stacks/finance

# Create data directories
sudo mkdir -p /opt/stacks/finance/data/{postgres,redis,firefly-iii/upload,importer}
sudo mkdir -p /opt/stacks/finance/data/paperless/{data,media,export}
sudo mkdir -p /opt/stacks/finance/data/ghostfolio
sudo chown -R 1000:1000 /opt/stacks/finance/data/

# Create backup directory
sudo mkdir -p /mnt/backups/finance
```

## Phase 2: Deploy Compose and Environment

```bash
# Copy docker-compose.yml and .env to stack directory
# .env must be populated from Infisical — NEVER edit .env directly

# Inject secrets from Infisical
infisical export --env=prod --projectId="<finance-stack-project-id>" \
  --format=dotenv > /opt/stacks/finance/.env

# Verify critical variables are set
grep -c "APP_KEY\|DB_PASSWORD\|FIREFLY_III_ACCESS_TOKEN" /opt/stacks/finance/.env
# Expected: 3+
```

## Phase 3: Deploy Containers

```bash
cd /opt/stacks/finance

# Pull latest images
docker compose pull

# Start all services
docker compose up -d

# Verify all containers running
docker compose ps
# Expected: 7 services, all "Up"
```

## Phase 4: Initial Firefly III Setup

On first deploy only:

1. **Access Firefly:** Browse to `https://firefly.ronny.works`
2. **Create admin account:** Use email from Infisical, strong password
3. **Generate PAT:** Profile → OAuth → Personal Access Tokens → Create
4. **Store PAT in Infisical:** Update `/finance-stack/prod/FIREFLY_ACCESS_TOKEN`

### Create Tags

Create these tags in Firefly III (used by automation):

| Tag | Purpose |
|-----|---------|
| `business` | Business expense marker |
| `personal` | Personal expense marker |
| `tax-deductible` | Tax deduction tracking |
| `synced-to-mintos` | Mint OS sync confirmation |
| `needs-review` | Manual review required |

### Create Accounts

Create all accounts per FINANCE_ACCOUNT_TOPOLOGY.md — bank accounts, credit cards, loans, payment processors, fixed assets.

### Create Categories

Create 38 categories per the category mapping in FINANCE_N8N_WORKFLOWS.md — 8 revenue, 8 COGS, 22 operating expenses.

### Set Up Auto-Categorization Rules

Configure Firefly rules to auto-categorize by payee name for major vendors (S&S Activewear, UPS, FedEx, SanMar, etc.).

## Phase 5: Configure Cloudflare Tunnel

Cloudflare tunnel ingress rules (managed via infra-core):

| Hostname | Service | Backend |
|----------|---------|---------|
| `firefly.ronny.works` | Firefly III | `http://127.0.0.1:8080` |
| `docs.ronny.works` | Paperless-ngx | `http://127.0.0.1:8000` |
| `finances.ronny.works` | Ghostfolio | `http://127.0.0.1:3333` |

> **Note:** Tunnel routes through infra-core Caddy with `extra_hosts` mapping to finance-stack Tailscale IP (100.76.153.100). See INFRASTRUCTURE_MAP.md for the full routing chain.

## Phase 6: Configure Backup Cron

```bash
# Add to finance-stack crontab
crontab -e

# Add line:
0 2 * * * /opt/stacks/finance/backup-finance-stack.sh >> /var/log/finance-backup.log 2>&1
```

See FINANCE_BACKUP_RESTORE.md for backup script details and restore procedures.

## Phase 7: Configure SimpleFIN Sync

```bash
# Add to finance-stack crontab
crontab -e

# Add line:
0 6 * * * /opt/stacks/finance/scripts/simplefin-daily-sync.sh >> /var/log/simplefin-sync.log 2>&1
```

See FINANCE_SIMPLEFIN_PIPELINE.md for SimpleFIN setup and troubleshooting.

## Phase 8: Configure Firefly Webhook (for n8n sync)

1. In Firefly III, go to **Admin → Webhooks**
2. Create webhook:
   - **URL:** `https://n8n.ronny.works/webhook/firefly/expense`
   - **Trigger:** `STORE_TRANSACTION`
   - **Response:** `TRANSACTIONS`
   - **Active:** Yes

See FINANCE_N8N_WORKFLOWS.md for the n8n workflow details.

## Phase 9: Configure Paperless-ngx

1. Access `https://docs.ronny.works`
2. Create admin account (first-time only)
3. Configure tags: `receipt`, `invoice`, `statement`, `linked`, `needs-review`
4. Configure correspondents for major vendors
5. Set up mail consumer (if email receipt forwarding desired)

## Verification Checklist

After deployment, verify each component:

| Check | Command / URL | Expected |
|-------|--------------|----------|
| Firefly API | `curl -H "Authorization: Bearer $PAT" https://firefly.ronny.works/api/v1/about` | JSON with version |
| Paperless API | `curl -H "Authorization: Token $TOKEN" https://docs.ronny.works/api/documents/` | JSON document list |
| Ghostfolio | Browse `https://finances.ronny.works` | Login page |
| PostgreSQL | `docker exec finance-postgres pg_isready` | "accepting connections" |
| Redis | `docker exec finance-redis redis-cli ping` | "PONG" |
| Backup cron | `crontab -l \| grep finance` | Backup entry present |
| SimpleFIN cron | `crontab -l \| grep simplefin` | Sync entry present |
| Container health | `docker compose -f /opt/stacks/finance/docker-compose.yml ps` | 7 services "Up" |

## Troubleshooting Quick Fixes

| Issue | Fix |
|-------|-----|
| Firefly 500 error | Check `APP_KEY` is set and 32 chars; `docker compose logs firefly-iii` |
| Database connection refused | `docker compose restart postgres`; wait 10s; retry |
| Cloudflare 502 | Verify tunnel is running on infra-core; check finance-stack port is reachable |
| Paperless upload fails | Check `/opt/stacks/finance/data/paperless/` permissions (1000:1000) |
| Out of disk | Check `/mnt/data/` usage; clean old backups |

## Rollback

To roll back to a previous state:

1. Stop all services: `docker compose down`
2. Restore database from backup (see FINANCE_BACKUP_RESTORE.md)
3. Pin images to previous versions in `docker-compose.yml`
4. Redeploy: `docker compose up -d`
