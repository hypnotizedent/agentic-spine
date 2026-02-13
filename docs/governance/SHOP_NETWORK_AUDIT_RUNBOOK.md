---
status: authoritative
owner: "@ronny"
created: 2026-02-09
last_verified: 2026-02-13
scope: shop-network-audit
---

# Shop Network Audit Runbook (Canonical)

> **Purpose:** One command to detect every kind of shop network drift — SSOT parity,
> live truth mismatches, and doc reference staleness.
>
> **Capabilities:**
> - `network.shop.audit.canonical` — full audit (read-only)
> - `network.shop.audit.status` — local parity only (no SSH)
> - `network.unifi.clients.snapshot` — UniFi client list (read-only)
> - `network.nvr.reip.canonical` — NVR re-IP fix (mutating)

---

## What Is "Canonical" vs "Live Truth"?

| Term | Meaning | Source |
|------|---------|--------|
| **Canonical** | What the SSOT says the IP *should* be | `DEVICE_IDENTITY_SSOT.md`, `ssh.targets.yaml` |
| **Live truth** | What the device *actually* responds to on the wire | `ping` + `ip neigh` + TCP probe via `pve` |
| **Parity** | Canonical sources agree with each other | binding ↔ SSOT docs |
| **Drift** | Live truth differs from canonical, or docs contain stale references | Any mismatch |

The audit detects all four categories.

---

## Running the Audit

### Full Canonical Audit (Recommended)

```bash
./bin/ops cap run network.shop.audit.canonical
```

This runs:
1. **Local parity** — binding ↔ SSOT doc agreement (no SSH needed)
2. **Live truth** — ping/neigh/TCP probes to every shop device via pve
3. **UniFi enrichment** — if creds available, maps MAC→IP to find moved devices
4. **Doc IP trace** — scans all governance docs for stale or unowned IP references

**Prerequisites:**
- pve reachable via Tailscale SSH
- yq, python3, jq installed locally

**Optional (for UniFi enrichment):**
- `UNIFI_SHOP_USER` + `UNIFI_SHOP_PASSWORD` in Infisical at `/spine/shop/unifi/`

### Local Parity Only (No SSH)

```bash
./bin/ops cap run network.shop.audit.status
```

Fast, offline check that SSOT docs and bindings agree on device IPs.

### UniFi Client Snapshot

```bash
./bin/ops cap run network.unifi.clients.snapshot
```

Lists all devices the UDR6 sees on the shop LAN (MAC, IP, hostname, wired/wireless).

---

## Interpreting Drift vs Normalization Debt

| Finding | What It Means | Action |
|---------|---------------|--------|
| `DRIFT: duplicate_ip` | Two devices claim same IP in bindings | Fix ssh.targets.yaml — one must be wrong |
| `DRIFT: binding=X SSOT=Y` | Binding and SSOT disagree | Determine which is correct, update the other |
| `DRIFT: missing_binding` | SSOT lists device, binding doesn't | Add to ssh.targets.yaml |
| `DRIFT: expected=X actual=UNREACHABLE` | Live device not at canonical IP | Device moved or is offline — fix device or update SSOT |
| `DRIFT: actual=MAC_UNKNOWN` | Device responds but neighbor/MAC identity could not be confirmed | Check L2 (VLAN, cabling), ARP/neigh health, and ensure `ssh.targets.yaml` has the correct `mac:` for the device |
| `DRIFT: actual=MAC_MISMATCH` | IP responds but it's the wrong device (identity collision) | Assume IP conflict or wrong reservation; find the MAC in UniFi, fix DHCP reservation/static IP, and update `ssh.targets.yaml` `mac:` if it truly changed |
| `DRIFT: found at Y by MAC Z` | UniFi found device at different IP | Re-IP device to canonical (see fixes below) |
| `DRIFT: stale_subnet_reference` | 192.168.12.x in docs (old subnet) | Update doc to use 192.168.1.x |
| `DRIFT: unowned_ip_reference` | IP in docs not in canonical set | Either add device to SSOT or remove stale reference |

**Normalization debt** = known items on the deferred list (iDRAC, switch re-IP) that
aren't blocking operations. These are tracked in `SHOP_NETWORK_DEVICE_ONBOARDING.md`
and `operational.gaps.yaml`, not treated as audit failures.

---

## Standard Fixes

### NVR (Hikvision) — Re-IP via ISAPI

```bash
# Auto-discover current IP via UniFi, re-IP to canonical:
./bin/ops cap run network.nvr.reip.canonical

# Or specify current IP manually:
./bin/ops cap run network.nvr.reip.canonical -- --current-ip <current-ip>
```

Uses Hikvision ISAPI (digest auth) through pve. Verifies with ping + MAC + HTTP.

### iDRAC — Re-IP via IPMI

```bash
# From pve:
ssh root@pve "ipmitool -I lanplus -H <current-ip> -U root -P <pass> \
  lan set 1 ipsrc static && \
  lan set 1 ipaddr 192.168.1.250 && \
  lan set 1 netmask 255.255.255.0 && \
  lan set 1 defgw ipaddr 192.168.1.1"
```

May need BMC cold reset if ARP table is stale.

### AP (TP-Link EAP225) — Via SSH or Web UI

SSH method (from pve via sshpass):
```bash
ssh root@pve "sshpass -p '<pass>' ssh -o StrictHostKeyChecking=no production@<current-ip> \
  'uci set network.lan.ipaddr=192.168.1.185 && uci commit && reboot'"
```

### Switch (Dell N2024P) — Via Console/SSH

Requires console cable or SSH access. CLI re-IP:
```
configure
interface vlan 1
ip address 192.168.1.2 255.255.255.0
exit
ip default-gateway 192.168.1.1
exit
write memory
```

---

## Writing Receipts + Closing Loops

Every audit and fix generates a receipt automatically via `ops cap run`:

```
Receipt:  mailroom/receipts/R<run-key>/receipt.md
Output:   mailroom/receipts/R<run-key>/output.txt
```

To close a drift loop:
1. Run the fix capability
2. Re-run `network.shop.audit.canonical` — must PASS
3. Run `network.cutover.preflight` — must return GO
4. Commit any doc fixes

---

## Related Documents

- [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) — canonical device identity
- [SHOP_NETWORK_DEVICE_ONBOARDING.md](SHOP_NETWORK_DEVICE_ONBOARDING.md) — onboarding checklist
- [NETWORK_RUNBOOK.md](NETWORK_RUNBOOK.md) — general network change procedures
- [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md) — shop hardware/topology
- [CAMERA_SSOT.md](CAMERA_SSOT.md) — NVR/camera details
