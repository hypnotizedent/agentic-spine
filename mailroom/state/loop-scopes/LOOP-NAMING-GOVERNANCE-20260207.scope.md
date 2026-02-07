# LOOP-NAMING-GOVERNANCE-20260207 — Scope Document

| Field | Value |
|-------|-------|
| Created | 2026-02-07T20:56Z |
| Owner | @ronny |
| Severity | high |
| Closes | GAP-OP-015 (PVE node-name mismatch), GAP-OP-016 (no naming governance) |
| Blocked by | Nothing (can start immediately) |

## Problem Statement

No naming governance policy exists. Each host has multiple identity surfaces
managed independently:

1. **System hostname** — `hostname` on the machine
2. **PVE node name** — `/etc/pve/nodes/<name>/` (hypervisors only)
3. **Tailscale hostname** — MagicDNS registration
4. **ssh.targets.yaml ID** — `ops/bindings/ssh.targets.yaml`
5. **DEVICE_IDENTITY_SSOT entry** — `docs/governance/DEVICE_IDENTITY_SSOT.md`
6. **SSH config Host alias** — `dotfiles/ssh/config.d/tailscale.conf`
7. **docker.compose.targets.yaml target** — `ops/bindings/docker.compose.targets.yaml`
8. **infra.placement.policy.yaml** — `ops/bindings/infra.placement.policy.yaml`

Changing one surface without updating the others causes breakage.

**Concrete damage (GAP-OP-015):** proxmox-home hostname was changed from `pve` to
`proxmox-home` but the PVE node was not migrated. Result: `qm list`, `pct list`,
`pct exec`, vzdump backup jobs — ALL BROKEN. VMs running pre-rename continue but
are unmanageable. VM 101 (immich) is stopped and cannot be restarted.

## Current Identity Surfaces (known mismatches marked)

| Host | System Hostname | PVE Node | Tailscale | ssh.targets ID | DEVICE_IDENTITY |
|------|----------------|----------|-----------|---------------|----------------|
| Shop hypervisor | `pve` | `pve` | `pve` | `pve` | `pve` |
| Home hypervisor | `proxmox-home` | **`pve`** (MISMATCH) | `proxmox-home` | `proxmox-home` | `proxmox-home` |
| Shop docker host | `docker-host` | N/A | `docker-host` | `docker-host` | `docker-host` |
| Home NAS | `nas` | N/A | `nas` | `nas` | `nas` |
| MacBook | `macbook` | N/A | `macbook` | N/A | `macbook` |
| infra-core | `infra-core` | N/A (VM) | `infra-core` | `infra-core` | `infra-core` |
| media-stack | `media` | N/A (VM) | `media-stack` | `media-stack` | `media-stack` |
| vaultwarden | `vault` | N/A (VM) | `vault` | `vault` | `vault` |
| automation | `automation` | N/A (VM) | `automation-stack` | `automation-stack` | `automation-stack` |
| pihole-home | `pihole-home` | N/A (LXC) | `pihole-home` | `pihole-home` | `pihole-home` |
| download-home | `download-home` | N/A (LXC) | `download-home` | `download-home` | `download-home` |
| Home Assistant | `homeassistant` | N/A (VM) | `ha` | `ha` | `ha` |

## Phases

### P0: Identity Surface Audit (read-only)

SSH to every reachable host, collect `hostname`, cross-reference with all 8
identity surface sources. Produce a complete mismatch report.

**Acceptance:** Machine-readable identity-surface-audit.yaml listing every host
with all 8 surface values and a `consistent: true/false` flag.

### P1: Naming Policy SSOT

Create `ops/bindings/naming.policy.yaml` defining:
- Canonical name per host (one name, all surfaces must match)
- Which surfaces are authoritative vs derived
- Rename procedure (ordered checklist of surfaces to update)
- Naming convention rules (already partially defined in DEVICE_IDENTITY_SSOT)

**Acceptance:** Policy file exists, references GAP-OP-016.

### P2: Fix proxmox-home Node-Name Mismatch (GAP-OP-015)

The canonical name is `proxmox-home` (matches `{function}-{location}` pattern).
The PVE node must be migrated from `pve` to `proxmox-home`.

**Procedure (from Proxmox docs):**
1. Stop all VMs/LXCs on proxmox-home
2. Verify `/etc/pve/nodes/pve/` contains: 100.conf, 101.conf, 102.conf (qemu-server), 103.conf, 105.conf (lxc)
3. Move configs: `cp -a /etc/pve/nodes/pve/* /etc/pve/nodes/proxmox-home/`
4. Verify copies
5. Remove old node dir: `rm -rf /etc/pve/nodes/pve/`
6. Restart `pvedaemon` and `pveproxy`
7. Verify `qm list` and `pct list` show all VMs/LXCs
8. Start VMs/LXCs
9. Re-enable vzdump backup jobs
10. Fix vzdump job referencing non-existent `synology-nas-storage`

**Acceptance:** `qm list` shows VMs 100-102, `pct list` shows LXCs 103/105,
vzdump jobs enabled, all workloads running.

**Safety:** This is a HIGH-RISK operation on a running hypervisor. VMs must be
shut down first. Rollback: rename hostname back to `pve` if config migration fails.

### P3: Naming Drift Gate (D45)

Create `surfaces/verify/d45-naming-consistency-lock.sh` that:
- Reads naming.policy.yaml
- Cross-references ssh.targets.yaml, DEVICE_IDENTITY_SSOT, docker.compose.targets, placement policy
- Fails if any host has mismatched identity surfaces

**Acceptance:** Gate passes for all hosts. Wired into drift-gate.sh.

### P4: Update DEVICE_IDENTITY_SSOT

- Add a "Naming Identity Surfaces" section documenting which surfaces exist per host type
- Fix verification commands (current `ssh proxmox-home "qm list"` is broken)
- Add note about PVE node name vs hostname distinction

**Acceptance:** DEVICE_IDENTITY_SSOT reflects reality post-P2 fix.

### P5: Closeout

- Mark GAP-OP-015 fixed
- Mark GAP-OP-016 fixed
- Close loop with evidence

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| PVE config migration corrupts VM configs | HIGH | Copy first (cp -a), verify, then remove old dir |
| VMs fail to start after migration | MEDIUM | Keep old hostname revert as rollback |
| Vaultwarden rollback source (VM 102) disrupted | HIGH | Ensure vaultwarden promotion completes first |
| NFS mounts break during VM shutdown | LOW | NFS is on NAS, not VM-dependent |

## Ordering Constraint

**P2 should wait until after vaultwarden promotion gate** (2026-02-08T04:41Z).
VM 102 (vaultwarden) is the rollback source for the infra-core migration. Shutting
it down during the soak window removes the rollback path. After promotion to
`migrated`, VM 102 rollback is no longer critical.

P0 and P1 can proceed immediately (read-only).

## Pre-Staged Artifact

- `ops/staged/NAMING_GOVERNANCE_P2_EXECUTION_PLAYBOOK_20260207.md`
  - Step-by-step mutation playbook + rollback for P2 execution once soak gate clears.
