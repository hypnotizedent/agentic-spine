---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-09
scope: shop-network
---

# Shop Network Device Onboarding (Canonical Runbook)

## Goal

No “new ways of doing things”.

Every new device (AP, printer, camera, switch, workstation, IoT) must be added
using the same spine-native workflow so agents always know:

- what the device is (`id`, model, role)
- where it is (location + switch port)
- how to reach it (LAN IP / Tailscale / URL)
- how its IP stays stable (DHCP reservation vs static)
- where credentials live (Infisical path, never in git)
- which SSOTs/bindings must be updated
- which checks prove it is canonical (receipts + drift gates)

## Definitions

- **Canonical ID**: short, stable `id` (kebab-case), used across bindings + SSOTs.
  Example: `ap-shop`, `printer-shop-front`, `nvr-shop`.
- **LAN-only**: device has no Tailscale and may not support SSH. It MUST still
  appear in `ops/bindings/ssh.targets.yaml` with `access_method: lan_only` and
  `probe_via: pve` so spine can health-check reachability.

## IP Policy (Normalization)

The *target* structure is defined in:

- `docs/governance/SHOP_NETWORK_NORMALIZATION.md`

Rule: prefer DHCP reservations on UDR6 for stability. Use true static only when
required.

## Onboarding Checklist (Every Device)

1. Pick canonical `id`
- Format: `<type>-<site>-<detail>` (kebab-case)
- Examples: `ap-shop`, `printer-shop-front`, `ups-shop`, `switch-shop`

2. Decide reachability class
- `tailscale` (preferred for servers)
- `ssh` (if it supports SSH and you intend to manage it that way)
- `lan_only` (most appliances/printers/APs/switch mgmt)

3. Assign stable management IP
- Choose IP following normalization rules.
- In UDR6, set a DHCP reservation for the device MAC → chosen IP.

4. Record credentials safely
- Store in Infisical under an explicit path:
  - Shop WiFi/AP: `infrastructure/prod:/spine/shop/wifi/*`
  - Shop printer: `infrastructure/prod:/spine/shop/printers/<id>/*`
  - Shop switch: `infrastructure/prod:/spine/shop/switch/*`
  - Shop iDRAC: `infrastructure/prod:/spine/shop/idrac/*`
- Never write passwords into git or receipts.

5. Add to bindings (runtime truth)
- Update `ops/bindings/ssh.targets.yaml`
  - If LAN-only: `access_method: lan_only`, `probe_via: pve`, `host: <mgmt-ip>`
  - If SSH-managed: `access_method` omitted (defaults to ssh) and `host` is
    Tailscale IP or LAN IP as appropriate

6. Update SSOT docs (human truth)
- Update `docs/governance/DEVICE_IDENTITY_SSOT.md` (identity map)
- Update `docs/governance/SHOP_SERVER_SSOT.md` (rack context + port map + URLs)
- If it exposes a service endpoint that matters, update the service map:
  - `docs/governance/SERVICE_REGISTRY.yaml` and/or `ops/bindings/services.health.yaml`

7. Generate receipts (proof)
- Confirm the new IP is real and who it is:
  - `./bin/ops cap run network.lan.host.identify --probe-via pve <ip>`
- Confirm spine can reach it (LAN-only):
  - `./bin/ops cap run network.lan.device.status <id>`

8. Enforce canon (no drift)
- `./bin/ops cap run network.shop.audit.status`
- `./bin/ops cap run spine.verify` (D54 enforces SSOT/binding parity)

## Device-Specific Notes

### New Access Point (AP)

Required facts to capture (after provisioning):
- `id`, model (EAP225), MAC
- management IP + reservation
- admin URL
- SSH enabled/disabled (if enabled, credentials path only)
- SSID(s) + which VLAN/LAN they map to (if any)
- firmware version
- switch port

### New Printer

Printers are typically `lan_only`. Required facts:
- `id`, model, physical location
- management IP + reservation
- web UI URL
- print protocol endpoints (AirPrint/IPP/JetDirect) if relevant
- driver notes (Mac/Windows)
- switch port

