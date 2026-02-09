---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-09
scope: shop-network
---

# Shop Network Normalization (Target)

## Goal

Make shop networking predictable for humans and agents:

- Every device has one canonical ID.
- Every device has one canonical management IP.
- IPs follow a consistent structure that can be inferred without archaeology.
- All drift is detectable via spine checks (bindings + SSOT parity locks).

This document defines the **target** structure. It may temporarily differ from
current reality during cutovers; when it does, open a loop and record receipts
for the change.

## Canonical Identity Rule

All shop-managed devices must have a stable `id` that appears in:

- `ops/bindings/ssh.targets.yaml` (runtime binding)
- `docs/governance/DEVICE_IDENTITY_SSOT.md` (identity map)
- `docs/governance/SHOP_SERVER_SSOT.md` (rack/network context)

Agents should use `id` everywhere (not hostnames guessed from UI labels).

## IP Structure (192.168.1.0/24)

### Reserved addresses

- `.1` UDR gateway/router
- `.2` switch management (Dell N2024P)
- `.184` Proxmox host (`pve`) (chosen; keep stable once set)

### Proxmox VMs (VMID parity)

Rule: for shop VMs, **IP last octet = VMID** (when feasible).

Examples:

- VM 200 → `192.168.1.200`
- VM 204 → `192.168.1.204`
- VM 210 → `192.168.1.210`

This reduces drift because you can infer IPs from Proxmox.

### LAN-only devices (non-Tailscale)

Rule: assign stable management IPs and declare them in `ssh.targets.yaml` as
`access_method: lan_only` with `probe_via: pve`.

Suggested ranges (not enforced yet):

- `.180-.199` core infra (hypervisor + APs)
- `.210-.239` cameras/NVR
- `.240-.254` BMC / out-of-band management

## DHCP Reservations vs Static

Preferred: DHCP reservations on UDR6 for all LAN devices.

- “Static” should mean “reservation-backed stable lease”, not manual per-host config.
- Exceptions: hypervisor host (`pve`) and any device that cannot do DHCP reliably.

## Drift Rules

- Any change to a shop management IP must be paired with:
  - a receipt proving the new IP (via `network.lan.host.identify` or equivalent), and
  - SSOT updates in `DEVICE_IDENTITY_SSOT.md` + `SHOP_SERVER_SSOT.md` + `ssh.targets.yaml`.
- `spine.verify` should fail if the SSOT/binding views diverge (see D54).

