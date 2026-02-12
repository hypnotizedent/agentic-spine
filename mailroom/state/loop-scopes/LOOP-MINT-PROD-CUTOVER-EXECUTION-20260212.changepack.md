# Change Pack: Mint Prod Cutover Execution

## Change Description

| Field | Value |
|------|-------|
| Change ID | LOOP-MINT-PROD-CUTOVER-EXECUTION-20260212 |
| Date | 2026-02-12 |
| Owner | @ronny |
| What | First production cutover of mint-modules unified compose on docker-host (VM 200) |
| Why | Consolidate artwork, order-intake, quote-page from per-module compose to unified prod compose |
| Downtime window | ~2 min (stop old containers, start new compose) |
| Rollback strategy | Restart old per-module containers from ~/artwork-module/ and ~/quote-page/ |

## IP Map

Software-only cutover — no IP changes.

| Service | Host | IP | Port | Change |
|---------|------|----|------|--------|
| files-api (artwork) | docker-host | 192.168.1.200 | 3500 | No change |
| order-intake | docker-host | 192.168.1.200 | 3400 | New service |
| quote-page | docker-host | 192.168.1.200 | 3341 | No change |

## Rollback Map

| Service | Rollback Action | Source |
|---------|----------------|--------|
| files-api | `cd ~/artwork-module && docker compose up -d` | Old per-module compose |
| quote-page | `cd ~/quote-page && docker compose up -d` | Old per-module compose |
| order-intake | Remove (new service, no prior state) | N/A |
| Database | `ALTER TABLE artwork_seeds DROP COLUMN metadata;` | Reverse migration |

## Pre-Cutover Verification Matrix

| Check | Method | Result |
|-------|--------|--------|
| spine.verify | `./bin/ops cap run spine.verify` | PASS (all gates) |
| ops status | `./bin/ops status` | 0 loops, 0 gaps |
| authority.project.status | `--repo-path mint-modules` | GOVERNED |
| promote --dry-run | `promote-to-prod.sh --dry-run` | PASS (all preflight) |
| SSH to docker-host | `ssh docker-host@192.168.1.200` | Connected |
| Docker running | `docker --version` | v28.2.2 |
| External networks | `docker network ls` | storage-network, mint-os-network present |
| Old containers healthy | `docker ps` | files-api (healthy), quote-page (healthy) |

## Cutover Sequence

1. Bootstrap `.env.prod` on docker-host:~/mint-modules-prod/ with secrets from running containers
2. Transfer module source to docker-host via rsync
3. Build 3 images on remote host (commit 0ce4de6)
4. Stop old files-api container (`cd ~/artwork-module && docker compose down`)
5. Stop old quote-page container (`cd ~/quote-page && docker compose down`)
6. Deploy unified compose (`docker compose -f docker-compose.prod.yml --env-file .env.prod up -d`)
7. Wait for healthchecks (10s stabilization)
8. Apply database migration (`ALTER TABLE artwork_seeds ADD COLUMN metadata jsonb DEFAULT NULL`)
9. Verify end-to-end intake → seed metadata flow

## LAN-Only Devices

No LAN-only device changes. All services on docker-host (192.168.1.200) accessible via LAN and Tailscale.

## Post-Cutover Verification Matrix

| Check | Method | Result |
|-------|--------|--------|
| files-api health | `curl :3500/health` | `{"status":"ok","db":"ok","minio":"ok"}` |
| order-intake health | `curl :3400/health` | `{"status":"ok","artwork_api":"ok"}` |
| quote-page health | `curl :3341/health` | `{"status":"ok","minio":"ok","files_api":"ok"}` |
| Container status | `docker ps` | All 3 healthy, image tag 0ce4de6 |
| Contract validation | `POST :3400/api/v1/intake/validate` | valid=true for valid payload |
| Negative validation | `POST :3400/api/v1/intake/validate` | valid=false, HTTP 422 for invalid |
| End-to-end intake | `POST :3400/api/v1/intake` | Seed created with metadata, has_line_item=true |
| Seed in artwork | `GET :3500/api/v1/seeds/:id` | Metadata populated correctly |
| Smoke script | `staging-integration-smoke.sh` | 6/6 passed (2 skipped — no API key) |

## Sign-Off

| Role | Name | Date | Status |
|------|------|------|--------|
| Operator | @ronny (via Claude Opus 4.6) | 2026-02-12 | Cutover successful |

## Image Digests

| Module | Image | Digest |
|--------|-------|--------|
| artwork | mint-modules/artwork:0ce4de6 | sha256:8b62ff0851a0 |
| order-intake | mint-modules/order-intake:0ce4de6 | sha256:3574dea3405f |
| quote-page | mint-modules/quote-page:0ce4de6 | sha256:2e53ae003bb2 |

## Database Migration

```sql
ALTER TABLE artwork_seeds ADD COLUMN metadata jsonb DEFAULT NULL;
```

Non-breaking: existing rows get NULL, code handles null gracefully.
