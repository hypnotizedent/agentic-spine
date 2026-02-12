# LOOP-MINT-FRESH-SLATE-TRAFFIC-CUTOVER-20260212

- **Status:** closed
- **Created:** 2026-02-12
- **Owner:** Terminal C (single-writer)
- **Parent:** LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-20260212
- **Depends on:** LOOP-MINT-FRESH-SLATE-UPLOAD-LEGACY-REMOVE-20260212 (closed)

## Goal

Cut over mint module public traffic (files-api, quote-page) from legacy docker-host
(VM 200, 100.92.156.118) to fresh-slate mint-apps (VM 213, 100.79.183.14).

## Operator Hard Rule

OLD MinIO stays untouched. No transfer, no stop, no delete, no config mutation on
legacy MinIO until explicit operator command.

## Routing Change

cloudflared extra_hosts on infra-core (VM 204):
- `files-api:100.92.156.118` → `files-api:100.79.183.14`
- `quote-page:100.92.156.118` → `quote-page:100.79.183.14`

No Caddy changes — mint services bypass Caddy (direct cloudflared → backend).

## Old MinIO Baseline Proof

- Container ID: `c29f2b8312b924b986ceabb64e313f58268f0591e8bc6134fe06c72c0a00296a`
- Started: `2026-02-11T18:18:20.931258793Z`
- Mount: `/mnt/docker/mint-os-data/minio` → `/data` (bind, rw)

## Phases

- P0: Baseline ✅ (spine.verify PASS, mint-apps 3/3, mint-data 3/3)
- P1: Pre-cutover gate ✅ (mint services healthy)
- P2: Cutover (cloudflared IP swap + restart) ✅
- P3: Post-cutover validation ✅
- P4: Closeout ✅

## Receipt IDs

- `CAP-20260212-100204__spine.verify__R2eez12130` (P0 baseline)
- `CAP-20260212-100232__services.health.status__Rifyo21689` (P0 baseline)
- `CAP-20260212-100249__docker.compose.status__Rcqwl22195` (P0 baseline)
- `CAP-20260212-100615__services.health.status__Rliio23292` (P3 post-cutover)
- `CAP-20260212-100637__docker.compose.status__Rqjyo23792` (P3 post-cutover)
- `CAP-20260212-100759__spine.verify__Rmpla34267` (P3 post-cutover, D53 pre-changepack)
- `CAP-20260212-100859__spine.verify__Rz6u743849` (P4 final — PASS)

## Rollback

```bash
ssh ubuntu@100.92.91.128 "sudo cp /opt/stacks/cloudflared/docker-compose.yml.bak-pre-mint-cutover /opt/stacks/cloudflared/docker-compose.yml && cd /opt/stacks/cloudflared && sudo docker compose up -d"
# Verify: grep -E 'files-api|quote-page' shows 100.92.156.118
```
