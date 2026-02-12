# Change Pack: Mint Fresh-Slate Traffic Cutover

## Change Description

| Field | Value |
|------|-------|
| Change ID | LOOP-MINT-FRESH-SLATE-TRAFFIC-CUTOVER-20260212 |
| Date | 2026-02-12 |
| Owner | Terminal C (single-writer) |
| What | Cut over mint module public traffic from docker-host to fresh-slate mint-apps VM |
| Why | Fresh-slate runtime is independent — no legacy DB dependency after upload loop closed |
| Downtime window | <5s (cloudflared container recreate) |
| Rollback strategy | Restore cloudflared backup, restart container |

## IP Map

| Service | Host (Before) | IP (Before) | Host (After) | IP (After) | Port | Change |
|---------|--------------|-------------|-------------|------------|------|--------|
| files-api | docker-host (VM 200) | 100.92.156.118 | mint-apps (VM 213) | 100.79.183.14 | 3500 | IP swap in cloudflared extra_hosts |
| quote-page | docker-host (VM 200) | 100.92.156.118 | mint-apps (VM 213) | 100.79.183.14 | 3341 | IP swap in cloudflared extra_hosts |
| order-intake | mint-apps (VM 213) | 100.79.183.14 | mint-apps (VM 213) | 100.79.183.14 | 3400 | No change (new service, no public route yet) |
| old MinIO | docker-host (VM 200) | 100.92.156.118 | docker-host (VM 200) | 100.92.156.118 | 9000 | **UNTOUCHED** |

## Rollback Map

| Service | Rollback Action | Source |
|---------|----------------|--------|
| cloudflared | `sudo cp docker-compose.yml.bak-pre-mint-cutover docker-compose.yml` | Backup on infra-core |
| cloudflared restart | `cd /opt/stacks/cloudflared && sudo docker compose up -d` | infra-core VM 204 |
| Staged file | `git revert <commit>` | Spine repo |

## Pre-Cutover Verification Matrix

| Check | Method | Result |
|-------|--------|--------|
| spine.verify | `./bin/ops cap run spine.verify` | PASS (all gates) |
| services.health | `./bin/ops cap run services.health.status` | files-api-v2 OK, quote-page-v2 OK, order-intake-v2 OK |
| docker.compose | `./bin/ops cap run docker.compose.status` | mint-apps 3/3, mint-data 3/3 |
| gaps.status | `./bin/ops cap run gaps.status` | 0 open gaps |
| Old MinIO baseline | `docker inspect minio` | ID=c29f2b8312b9, started=2026-02-11T18:18:20Z, mount=/mnt/docker/mint-os-data/minio |

## Cutover Sequence

1. Edit `ops/staged/cloudflared/docker-compose.yml`: change `files-api` and `quote-page` IPs from `100.92.156.118` to `100.79.183.14`
2. SSH to infra-core (ubuntu@100.92.91.128): backup current compose (`cp .bak-pre-mint-cutover`)
3. `sed` replace IPs on live file (two lines only)
4. `docker compose up -d` to recreate cloudflared container with new extra_hosts
5. Verify cloudflared logs show 4 tunnel connections registered
6. Smoke test: `curl 100.79.183.14:3500/health` and `:3341/health` return 200

## LAN-Only Devices

No LAN-only device changes. Cutover is cloudflared DNS-level only (Tailscale IPs in extra_hosts). Legacy services on docker-host continue operating on same LAN IP (192.168.1.200).

## Post-Cutover Verification Matrix

| Check | Method | Result |
|-------|--------|--------|
| files-api-v2 health | services.health.status | OK (208ms) |
| quote-page-v2 health | services.health.status | OK (255ms) |
| order-intake-v2 health | services.health.status | OK (304ms) |
| mint-data stack | docker.compose.status | 3/3 |
| mint-apps stack | docker.compose.status | 3/3 |
| spine.verify | `./bin/ops cap run spine.verify` | PASS (`CAP-20260212-100859__spine.verify__Rz6u743849`) |
| Old MinIO unchanged | `docker inspect minio` | Same ID=c29f2b8312b9, same start=2026-02-11T18:18:20Z |

## Sign-Off

| Role | Name | Date | Status |
|------|------|------|--------|
| Operator | @ronny (via Claude Opus 4.6, Terminal C) | 2026-02-12 | Cutover successful |
