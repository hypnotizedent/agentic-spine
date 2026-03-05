---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
scope: reboot-validation
github_issue: "#610"
---

# Reboot Health Gate

> **Purpose:** Operational governance for safe infrastructure reboots.
> Defines pre-reboot checks, post-reboot verification, and rollback criteria.

---

## Pre-Reboot Checklist

Before rebooting any Tier 1 or Tier 2 node:

- [ ] **No active deploys:** Check `docker ps` for in-progress operations.
- [ ] **Backup fresh:** Last backup < 24 hours (`./bin/ops cap run backup.status`).
- [ ] **Drift gates pass:** `./bin/ops cap run spine.verify` exits 0.
- [ ] **Notify:** Post to relevant channel that reboot is starting.

## Hard Stop Conditions (Legacy Parity Accepted 2026-02-17)

Do not proceed until resolved:

| Condition | Check Command | Why It Is Blocking |
|---|---|---|
| ZFS pool degraded/faulted | `ssh pve "zpool status | grep -E 'DEGRADED|FAULTED'"` | Reboot risks data loss during unstable storage state |
| Active vzdump running | `ssh pve "pgrep vzdump"` | Reboot can corrupt backup jobs |
| VM migration in progress | `ssh pve "qm list | grep migrating"` | Reboot during migration risks VM state corruption |
| Root disk critically low | `ssh pve "df -h / | tail -1"` | Low space can cause failed boot/recovery |

---

## Post-Reboot Verification

After the node is back online:

```bash
# Quick check: what needs recovery?
./bin/ops cap run infra.post_power.recovery.status

# Orchestrated recovery: bring all stacks up in dependency order
./bin/ops cap run infra.post_power.recovery

# Verify Docker stacks recovered
./bin/ops cap run docker.compose.status

# Verify service health
./bin/ops cap run services.health.status

# Run full drift gates
./bin/ops cap run spine.verify
```

If a service appears offline, check VM runtime state before diagnosing network
paths: `ssh pve "qm list"` (stopped VM is not a network outage).

**Recovery sequencing** is declared in `ops/bindings/startup.sequencing.yaml`:
1. Core infra (secrets, caddy, pihole, vaultwarden, cloudflared)
2. Observability + dev tools (prometheus, grafana, gitea)
3. Application workloads (n8n, download-stack, streaming-stack)
4. Legacy production (docker-host: mint-os, finance, mail-archiver)

The recovery capability handles the common post-power-cycle failure mode where
containers exit with code 128 (SIGKILL) and Docker doesn't auto-restart them.
It runs `compose down --remove-orphans` to clean up stale containers before
`compose up -d`.

---

## Rollback Criteria

Escalate (do not proceed with further reboots) if:

1. Any Tier 1 service fails to come back within 5 minutes.
2. More than 2 Docker stacks fail to start.
3. Drift gates report new failures not present before reboot.

---

## Node Tiers

| Tier | Impact | Examples |
|------|--------|----------|
| 1 | Production-critical | docker-host, pve |
| 2 | Important services | media stack, n8n |
| 3 | Development/test | Dev VMs |
| 4 | Optional | Homelab experiments |

See [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) for the full node inventory.

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [BACKUP_GOVERNANCE.md](BACKUP_GOVERNANCE.md) | Backup freshness rules |
| [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) | Node identity and tiers |
| [STACK_REGISTRY.yaml](STACK_REGISTRY.yaml) | Stack inventory |
