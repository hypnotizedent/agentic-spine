# Naming Governance P2 Execution Playbook

| Field | Value |
|---|---|
| Loop | `LOOP-NAMING-GOVERNANCE-20260207` |
| Phase | `P2` |
| Scope | Fix proxmox-home PVE node-name mismatch (`/etc/pve/nodes/pve` -> `/etc/pve/nodes/proxmox-home`) |
| Risk | High (hypervisor control-plane mutation) |
| Blocker | Vaultwarden promotion execute must complete first |

## Blocker Gate (Must Be Cleared First)

1. Promotion executed (vaultwarden migrated):
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
# Dry-run first (prints what will migrate and which guests are running)
echo "yes" | ./bin/ops cap run infra.proxmox.node_path.migrate \
  --host-id proxmox-home --from-node pve --to-node proxmox-home --dry-run

# Execute (receipt-backed)
# - backs up /etc/pve/nodes/pve to /root/pve-node-backup-<ts>
# - copies qemu-server/* + lxc/* into /etc/pve/nodes/proxmox-home/
# - retires the stale node dir to /etc/pve/nodes/pve.stale.<ts>
# - restarts pvedaemon + pveproxy
# - stops and restarts only guests that were running at start time
echo "yes" | ./bin/ops cap run infra.proxmox.node_path.migrate \
  --host-id proxmox-home --from-node pve --to-node proxmox-home --execute
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
