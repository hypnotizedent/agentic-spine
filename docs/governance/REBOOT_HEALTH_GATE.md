---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-04
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

---

## Post-Reboot Verification

After the node is back online:

```bash
# Verify SSH connectivity
./bin/ops cap run ssh.target.status

# Verify Docker stacks recovered
./bin/ops cap run docker.compose.status

# Verify service health
./bin/ops cap run services.health.status

# Run full drift gates
./bin/ops cap run spine.verify
```

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
