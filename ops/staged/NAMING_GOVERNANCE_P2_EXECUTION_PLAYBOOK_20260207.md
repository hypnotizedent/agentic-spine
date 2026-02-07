# Naming Governance P2 Execution Playbook

| Field | Value |
|---|---|
| Loop | `LOOP-NAMING-GOVERNANCE-20260207` |
| Phase | `P2` |
| Scope | Fix proxmox-home PVE node-name mismatch (`/etc/pve/nodes/pve` -> `/etc/pve/nodes/proxmox-home`) |
| Risk | High (hypervisor control-plane mutation) |
| Blocker | Vaultwarden promotion execute must complete first |

## Blocker Gate (Must Be Cleared First)

1. Promotion executed at/after `2026-02-08T04:41:00Z`:
   `infra.relocation.promote --service vaultwarden --execute`
2. Service state confirmed migrated in relocation manifest.
3. Rollback posture accepted for VM 102.

## Preflight (Read-Only)

```bash
./bin/ops cap run infra.hypervisor.identity
./bin/ops cap run infra.relocation.parity
surfaces/verify/d45-naming-consistency-lock.sh
ssh proxmox-home 'hostname; pveversion -v | head -1'
ssh proxmox-home 'ls -1 /etc/pve/nodes'
ssh proxmox-home 'qm list; pct list'
ssh proxmox-home 'cat /etc/pve/jobs.cfg'
```

## Execution Steps (On proxmox-home)

```bash
# 1) Stop guest workloads cleanly
ssh proxmox-home 'for id in 100 101 102; do qm stop "$id" || true; done'
ssh proxmox-home 'for id in 103 105; do pct stop "$id" || true; done'

# 2) Backup current cluster node config
ssh proxmox-home 'ts=$(date +%Y%m%d-%H%M%S); cp -a /etc/pve/nodes/pve "/root/pve-node-backup-$ts" && echo "backup=/root/pve-node-backup-$ts"'

# 3) Copy configs into canonical node path
ssh proxmox-home 'mkdir -p /etc/pve/nodes/proxmox-home/qemu-server /etc/pve/nodes/proxmox-home/lxc'
ssh proxmox-home 'cp -a /etc/pve/nodes/pve/qemu-server/*.conf /etc/pve/nodes/proxmox-home/qemu-server/'
ssh proxmox-home 'cp -a /etc/pve/nodes/pve/lxc/*.conf /etc/pve/nodes/proxmox-home/lxc/'

# 4) Verify copied configs before deleting old node path
ssh proxmox-home 'ls -1 /etc/pve/nodes/proxmox-home/qemu-server'
ssh proxmox-home 'ls -1 /etc/pve/nodes/proxmox-home/lxc'

# 5) Remove stale node path and restart PVE services
ssh proxmox-home 'rm -rf /etc/pve/nodes/pve'
ssh proxmox-home 'systemctl restart pvedaemon pveproxy'

# 6) Verify control plane recovery
ssh proxmox-home 'qm list; pct list'

# 7) Start guests
ssh proxmox-home 'for id in 100 101 102; do qm start "$id" || true; done'
ssh proxmox-home 'for id in 103 105; do pct start "$id" || true; done'

# 8) Re-enable/validate backup jobs
ssh proxmox-home 'grep -n "^vzdump:" /etc/pve/jobs.cfg'
```

## Post-Execution Verification

```bash
surfaces/verify/d45-naming-consistency-lock.sh
./bin/ops cap run spine.verify
./bin/ops cap run infra.relocation.parity
```

## Rollback

```bash
# If PVE control-plane commands fail after migration:
ssh proxmox-home 'mv /etc/pve/nodes/proxmox-home /etc/pve/nodes/proxmox-home.failed.$(date +%s)'
ssh proxmox-home 'cp -a /root/pve-node-backup-<timestamp> /etc/pve/nodes/pve'
ssh proxmox-home 'systemctl restart pvedaemon pveproxy'
ssh proxmox-home 'qm list; pct list'
```

## Acceptance

1. `qm list` and `pct list` both return expected guests on proxmox-home.
2. VM 101 is startable again.
3. vzdump jobs validate with no stale node-path references.
4. D45 + spine.verify pass.
