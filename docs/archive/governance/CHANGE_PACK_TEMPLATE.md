---
status: template
owner: "@ronny"
created: 2026-02-09
scope: network-operations
last_verified: 2026-02-23
---

# Change Pack Template

Purpose: a single, copy/paste execution artifact for a network change. This is the
"script" that prevents mid-cutover improvisation.

Usage: Copy this file to `mailroom/state/loop-scopes/<LOOP-ID>.changepack.md` and
fill in every section. The companion changepack file is required for any cutover loop
and is enforced by D53 (change-pack-integrity-lock).

Authority boundary:
- Device naming/identity: `docs/governance/DEVICE_IDENTITY_SSOT.md`
- Network governance: `docs/governance/NETWORK_POLICIES.md`
- Location hardware: `docs/governance/SHOP_SERVER_SSOT.md` / `docs/governance/MINILAB_SSOT.md`
- Cutover sequencing: `ops/bindings/cutover.sequencing.yaml`

## Change Description

| Field | Value |
|------|-------|
| Change ID | LOOP-... |
| Date | YYYY-MM-DD |
| Owner | @... |
| What | (one sentence) |
| Why | (one sentence) |
| Downtime window | (estimate) |
| Rollback strategy | (one sentence + concrete revert map) |

## IP Map (Old -> New)

| Device | Old IP | New IP | Config Location | Method |
|--------|--------|--------|-----------------|--------|
| (router) | | | | |
| (hypervisor) | | | | |
| (VMs) | | | | |
| (LAN-only devices) | | | | |

## Rollback Map

| Device | Revert IP | Config File | Revert Command |
|--------|-----------|-------------|----------------|
| (device) | x.x.x.x | (path) | (command) |

## Pre-Cutover Verification Matrix

Receipt-anchored checks that MUST pass before P2 physical cutover begins.

- [ ] `./bin/ops cap run spine.verify` is PASS (or known failures listed below)
- [ ] `./bin/ops cap run ssh.target.status` is PASS for all in-scope targets (exceptions listed)
- [ ] `./bin/ops cap run docker.compose.status` is PASS for in-scope stacks (exceptions listed)
- [ ] `./bin/ops cap run services.health.status` is PASS for Tier-1 endpoints (exceptions listed)
- [ ] `./bin/ops cap run network.cutover.preflight` is GO

Known acceptable pre-existing failures:
- (list exact IDs + reason)

## Cutover Sequence

Per `ops/bindings/cutover.sequencing.yaml`, execute in this order:

| Step | Phase | Action | Where |
|------|-------|--------|-------|
| 1 | Remote management | Verify Tailscale stable to all in-scope targets | macbook |
| 2 | Hypervisor | Ensure PVE reachable on new subnet | pve |
| 3 | Switch | Re-IP switch management interface | on-site or remote |
| 4 | LAN-only devices | Re-IP iDRAC, NVR, AP | on-site or via probe_via host |
| 5 | Workloads | Touch dependent services (NFS remount, docker restart) | VMs |

### Execution Steps (Copy/Paste)

Each step must include: What / Where / Command / Verify / Rollback.

| Step | What | Where | Command | Verify | Rollback |
|------|------|-------|---------|--------|----------|
| 1 | | | | | |
| 2 | | | | | |

## LAN-Only Devices (On-Site Section)

This section exists so you do not discover "console-only" work mid-cutover.

| Device | On-site required? | Re-IP procedure | Verify |
|--------|-------------------|-----------------|--------|
| switch | yes/no | (see NETWORK_RUNBOOK.md) | |
| iDRAC | yes/no | (see NETWORK_RUNBOOK.md) | |
| NVR | yes/no | (see NETWORK_RUNBOOK.md) | |

## Post-Cutover Verification Matrix

| Check | Command | Expected | Status |
|-------|---------|----------|--------|
| Gateway reachable | `ping -c1 <gw>` | OK | [ ] |
| PVE vmbr0 IP | `ssh pve "ip -4 addr show vmbr0"` | new IP | [ ] |
| VM LAN IPs | `ssh <vm> "ip -4 addr"` | new IP(s) | [ ] |
| NFS mounts | `ssh <vm> "findmnt -t nfs,nfs4"` | LAN source | [ ] |
| CF endpoints | `curl -I https://...` | 200/expected | [ ] |
| Pi-hole DNS | `dig @<pihole> example.com A` | NOERROR | [ ] |
| LAN-only devices | `ping -c1 <device_ip>` from pve | OK | [ ] |

## Deferred Items

Items discovered during cutover that are out-of-scope for this change pack.

| Item | Why Deferred | Follow-up Loop |
|------|-------------|----------------|
| (item) | (reason) | LOOP-... |

## Documentation Sweep

Per NETWORK_RUNBOOK.md Section 9, update after every cutover:

- [ ] `docs/governance/DEVICE_IDENTITY_SSOT.md` -- subnet table, LAN endpoints, VM LAN IPs
- [ ] `docs/governance/SHOP_SERVER_SSOT.md` -- network section, switch ports, NFS exports
- [ ] `docs/governance/NETWORK_POLICIES.md` -- subnet allocation, DNS strategy
- [ ] `docs/governance/CAMERA_SSOT.md` -- NVR IP references
- [ ] `ops/bindings/infra.relocation.plan.yaml` -- CIDR entries
- [ ] `ops/bindings/operational.gaps.yaml` -- close/update relevant gaps
- [ ] Memory files -- update IPs in MEMORY.md and infrastructure-details.md

## Sign-Off

| Milestone | Timestamp | Receipt/Evidence |
|-----------|-----------|------------------|
| Preflight PASS | | |
| P2 cutover complete | | |
| P3 verification PASS | | |
| Docs sweep complete | | |
| Loop closed | | |
