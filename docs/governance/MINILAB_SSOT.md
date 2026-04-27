---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-27
verification_method: generated-readmodel
scope: home-control-plane-summary
---

# MINILAB SSOT

Thin pointer to structured authority and generated read model.

Factual home infrastructure tables are no longer maintained here. They are
generated from canonical structured bindings by a governed capability.

## Authority Sources

- **VM lifecycle:** `ops/bindings/vm.lifecycle.yaml` (home VMs: proxmox_host=proxmox-home)
- **SSH targets:** `ops/bindings/ssh.targets.yaml` (home targets: site=home)
- **Backup inventory:** `ops/bindings/domains/backup/backup.inventory.yaml`
- **Naming/topology conventions:** `docs/governance/DEVICE_IDENTITY_SSOT.md`

## Generated Read Model

```bash
./bin/ops cap run infra.minilab.readmodel.generate
```

Output: `$SPINE_STATE/domain-state/infra.minilab.readmodel.md`

## Detailed Home Infrastructure

Hardware specs, RAID configs, NFS exports, backup schedules, and operator
runbooks live in the workbench:

`~/code/workbench/docs/infrastructure/domains/home/MINILAB_SSOT.md`
