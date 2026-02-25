---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-25
scope: app-backup-restore
---

# Stalwart Backup + Restore (App-Level)

Purpose: define a recoverable backup/restore procedure for Stalwart mail on
`communications-stack` (VM 214) beyond VM-level `vzdump`.

## Backup Scope

Required components:
1. Runtime config: `stalwart.toml`
2. TLS + ACME state (mail cert chain and ACME account/challenge state)
3. Mailbox data volume: `communications-stack_stalwart-data`
4. Secrets required to reconstruct runtime auth/materialized env

## Identify Live Paths (Do Not Guess)

Run on VM 214 to discover current mounts/paths:

```bash
ssh communications-stack '
set -euo pipefail
docker inspect stalwart-mail --format "{{json .Mounts}}" | jq
docker volume inspect communications-stack_stalwart-data
'
```

Use discovered mount locations for config/certs backups.

## Backup Procedure

1. Backup config + cert/acme directories:

```bash
ssh communications-stack '
set -euo pipefail
ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="/tmp/stalwart-config-${ts}.tar.gz"
# Replace these two paths with values from docker inspect output:
cfg_dir="/opt/stacks/communications/stalwart"
tls_dir="/opt/stacks/communications/certs"
tar -czf "$out" -C / "$cfg_dir" "$tls_dir"
ls -lh "$out"
'
```

2. Backup mailbox data volume:

```bash
ssh communications-stack '
set -euo pipefail
ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="/tmp/stalwart-data-${ts}.tar.gz"
docker run --rm \
  -v communications-stack_stalwart-data:/data:ro \
  -v /tmp:/backup \
  alpine sh -c "tar -czf /backup/stalwart-data-${ts}.tar.gz -C /data ."
ls -lh "$out"
'
```

3. Sync to NAS archive:

```bash
ssh communications-stack '
set -euo pipefail
dst="ronadmin@100.102.199.111:/volume1/backups/apps/stalwart"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ronadmin@100.102.199.111 "mkdir -p /volume1/backups/apps/stalwart"
rsync -az --timeout=120 /tmp/stalwart-config-*.tar.gz "$dst/"
rsync -az --timeout=120 /tmp/stalwart-data-*.tar.gz "$dst/"
'
```

## Secrets Recovery

Canonical namespace: `/spine/services/communications`

Minimum keys to recover:
- `STALWART_OPS_PASSWORD`
- `STALWART_ALERTS_PASSWORD`
- `STALWART_NOREPLY_PASSWORD`

Validation command:

```bash
./bin/ops cap run secrets.namespace.status
```

## Restore Procedure

1. Re-provision stack host/container runtime.
2. Stop Stalwart.
3. Restore config + cert/acme archive into discovered mount paths.
4. Restore data volume:

```bash
ssh communications-stack '
set -euo pipefail
archive="/tmp/STALLWART_DATA.tar.gz"   # replace
docker run --rm \
  -v communications-stack_stalwart-data:/data \
  -v /tmp:/backup \
  alpine sh -c "rm -rf /data/* && tar -xzf $archive -C /data"
'
```

5. Rehydrate env/secrets from Infisical and start container.
6. Validate SMTP/IMAP/HTTPS:

```bash
./bin/ops cap run communications.tls.status
./bin/ops cap run communications.stack.status
```

## DNS + ACME Re-Bootstrap

If cert issuance fails after restore:
1. Verify canonical mail DNS (A/MX/SPF/DKIM/DMARC) is unchanged.
2. Re-run communications verification pack:

```bash
./bin/ops cap run verify.pack.run communications
```

3. Confirm ACME challenge path and mail hostname resolve externally before retry.

## Break-Glass

If Stalwart is down and notifications must continue:
1. Route urgent outbound notifications through approved fallback provider path
   (communications send surfaces) until Stalwart health returns.
2. Keep incident receipts for fallback period and close with Stalwart recovery evidence.
