---
loop_id: LOOP-DOCKER-HOST-SAFE-DEPRECATION-BATCH-20260226-20260226
created: 2026-02-26
status: active
owner: "@ronny"
scope: docker
priority: high
objective: Execute docker-host legacy cleanup through governed, non-rogue batches with strict before/after receipts and explicit mint/runtime deferrals
---

# Loop Scope: LOOP-DOCKER-HOST-SAFE-DEPRECATION-BATCH-20260226-20260226

## Objective

Execute docker-host legacy cleanup through governed, non-rogue batches with strict before/after receipts and explicit mint/runtime deferrals

## Phases
- P0: read-only-evidence-trace-and-ranking
- P1: close-audit-chain-gaps-mcp-routing-secrets
- P2: tier1-cleanup-batch-with-receipts
- P3: post-batch-verify-and-gap-closeout

## Success Criteria
- No destructive docker-host cleanup occurs outside governed capabilities and receipts
- Tier1 cleanup items are executed in one approved batch with verify follow-through

## Definition Of Done
- Canonical trace artifact recorded with run keys
- All verify_first/defer items remain gated until proof exists

## Canonical Trace (Read-Only Evidence)

### Evidence receipts
- `CAP-20260225-232828__infra.docker_host.status__Rw3dd88349`
- SSH snapshot (volumes/dirs/cron/script presence) from this session
- `CAP-20260225-232206__cloudflare.tunnel.ingress.status__Rmcd771900`
- `CAP-20260225-232337__services.health.status__Rxemj78010`

### Tier 1 candidates (safe_cleanup_now class)
- `orphaned-volumes-pihole-secrets`: PRESENT on docker-host, zero attached containers
- `stacks/finance`: PRESENT (80K), canonical runtime on `finance-stack`
- `stacks/pihole`: PRESENT (12K), canonical runtime on `infra-core`
- `stacks/cloudflared`: PRESENT (12K), canonical runtime on `infra-core`
- `stacks/secrets`: PRESENT (20K), canonical runtime on `infra-core`
- stale cron `backup-finance.sh`: PRESENT in crontab
- stale cron `backup-infrastructure.sh`: PRESENT in crontab
- stale cron `backup-media-configs.sh`: PRESENT in crontab
- stale cron `check-secret-expiry.sh`: PRESENT in crontab

### Tier 2 candidates (verify_first class)
- `stacks/mail-archiver`: PRESENT (24K) on docker-host; requires verify receipt before cleanup
- `~/scripts/simplefin-daily-sync.sh`: PRESENT; not currently in crontab

### Deferred candidates (do not mutate in this loop)
- `stacks/infrastructure` (verify_first)
- `stacks/mint-os-data` (verify_first)
- `sync-to-synology.sh` cron (verify_first)
- GitHub actions runner on docker-host (verify_first)
- all Mint runtime class services (`defer_mint_lane`)

## Audit Chain Gaps Filed
- `GAP-OP-960`: missing governed receipt chain for manual mcpjungle verify_first deletion
- `GAP-OP-961`: stale routing hint for `mcp.mintprints.co` docker-host reference
- `GAP-OP-962`: missing secret-rotation evidence after historical MCPJungle plaintext exposure

## Non-Rogue Execution Guard

Before any destructive batch:
1. Confirm pre-state receipts:
`./bin/ops cap run infra.docker_host.status`
2. Confirm queue/dispatcher health:
`./bin/ops cap run communications.alerts.queue.status`
`./bin/ops cap run communications.alerts.dispatcher.status`
3. Execute only Tier 1 set from `ops/bindings/docker-host.deprecation.contract.yaml`.
4. Re-run status + verify:
`./bin/ops cap run verify.route.recommend`
`./bin/ops cap run verify.pack.run infra`
5. Close gaps with `gaps.close` using run keys from this loop only.

## Tier 1 Batch Execution (2026-02-26)

Execution status: completed (Tier 1 only).

### Mutations applied on docker-host
- Removed orphan volumes:
  - `pihole_pihole_config`
  - `pihole_pihole_dnsmasq`
  - `secrets_pg_data`
  - `secrets_redis_data`
- Removed zombie dirs:
  - `~/stacks/finance`
  - `~/stacks/pihole`
  - `~/stacks/cloudflared`
  - `~/stacks/secrets`
- Removed stale cron entries:
  - `backup-finance.sh`
  - `backup-infrastructure.sh`
  - `backup-media-configs.sh`
  - `check-secret-expiry.sh`
- Cron backups written on docker-host:
  - `/home/docker-host/backups/crontab.pre_tier1_20260226T043418Z.txt`
  - `/home/docker-host/backups/crontab.post_tier1_20260226T043418Z.txt`

### Pre-state run keys
- `CAP-20260225-233402__infra.docker_host.status__Rt7qh43210`
- `CAP-20260225-233402__communications.alerts.queue.status__R66e343211`
- `CAP-20260225-233402__communications.alerts.dispatcher.status__Rspak43212`

### Post-state validation
- Volumes absent (4/4): verified via ssh post-check.
- Tier 1 dirs absent (4/4): verified via ssh post-check.
- Deferred dirs untouched:
  - `~/stacks/mail-archiver` present
  - `~/stacks/infrastructure` present
  - `~/stacks/mint-os-data` present
- Target stale cron lines removed; keep-crons still present (`sync-to-synology`, mint backup jobs, watchdog, docker prune).

### Post-state run keys
- `CAP-20260225-233434__infra.docker_host.status__R5g0b53180`
- `CAP-20260225-233434__communications.alerts.queue.status__Rojvl53181`
- `CAP-20260225-233434__communications.alerts.dispatcher.status__R4nnz53182`
- `CAP-20260225-233434__verify.route.recommend__Rzxyh53183`
- `CAP-20260225-233442__verify.pack.run__Rhpb456159` (failed on pre-existing stale network snapshot gates D188/D194; unrelated to Tier 1 cleanup actions)
