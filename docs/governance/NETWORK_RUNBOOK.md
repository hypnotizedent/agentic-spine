---
status: authoritative
owner: "@ronny"
created: 2026-02-09
scope: network-operations
---

# Network Change Runbook

> Reusable procedures for network changes across the homelab.
>
> **Covers:** IP changes, subnet migrations, NFS re-exports, Tailscale route updates,
> and device-specific re-IP procedures.
>
> **Authority boundary:**
> - Device naming/identity: [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md)
> - Shop hardware/topology: [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md)
> - Network policies: [NETWORK_POLICIES.md](NETWORK_POLICIES.md)
> - Shop audit + fix workflow: [SHOP_NETWORK_AUDIT_RUNBOOK.md](SHOP_NETWORK_AUDIT_RUNBOOK.md)

---

## 1. Change Description Template

Before any network change, document:

| Field | Value |
|-------|-------|
| **Change ID** | LOOP-{description}-{date} |
| **What** | (e.g., "Re-IP shop LAN from <old-subnet>/24 to 192.168.1.0/24") |
| **Why** | (e.g., "T-Mobile gateway locked, need DHCP/DNS control") |
| **Downtime estimate** | (e.g., "30-60 min maintenance window") |
| **Rollback plan** | (e.g., "Revert configs, reconnect original cable") |

Recommended artifact:
- Create a per-change "Change Pack" using `docs/governance/CHANGE_PACK_TEMPLATE.md` (see Section 9).

---

## 2. Impact Assessment

Enumerate all affected devices and services:

- [ ] List every device that needs an IP change
- [ ] List every NFS mount that references old IPs
- [ ] List every fstab entry that needs updating
- [ ] List every SSOT doc that references old IPs
- [ ] Identify services that auto-reconnect (Cloudflare tunnel, Tailscale) vs. manual restart
- [ ] Identify LAN-only devices (switch, iDRAC, NVR, AP) — these need on-site or remote re-IP

---

## 3. Pre-Flight Checklist

- [ ] Backups verified fresh (vzdump, app-level)
- [ ] All config changes pre-staged (written but not applied)
- [ ] Rollback procedure documented and tested mentally
- [ ] Tailscale connectivity verified (fallback SSH path)
- [ ] Maintenance window communicated

---

## 4. IP Map Template

| Device | Old IP | New IP | Config Location | Re-IP Method |
|--------|--------|--------|-----------------|--------------|
| (device) | x.x.x.x | y.y.y.y | (path) | (method) |

---

## 5. Execution Step Template

Each step should include:
1. **What** — the action
2. **Where** — SSH target or physical location
3. **Command** — exact command to run
4. **Verify** — how to confirm success
5. **Rollback** — how to undo if it fails

---

## 6. Verification Matrix Template

| Check | Command | Expected | Status |
|-------|---------|----------|--------|
| (description) | (command) | (expected output) | [ ] |

---

## 7. Documentation Sweep

After any network change, update:

- [ ] `docs/governance/DEVICE_IDENTITY_SSOT.md` — subnet table, LAN endpoints, VM LAN IPs
- [ ] `docs/governance/SHOP_SERVER_SSOT.md` — network section, switch ports, NFS exports
- [ ] `docs/governance/NETWORK_POLICIES.md` — subnet allocation, DNS strategy
- [ ] `docs/governance/CAMERA_SSOT.md` — NVR IP references
- [ ] `ops/bindings/infra.relocation.plan.yaml` — CIDR entries
- [ ] `ops/bindings/operational.gaps.yaml` — close/update relevant gaps
- [ ] Memory files — update IPs in MEMORY.md and infrastructure-details.md

---

## 8. Post-Change Monitoring (24-48h)

- [ ] Tailscale status — all nodes online
- [ ] NFS mounts stable — no D-state processes
- [ ] Cloudflare tunnel — all routes healthy
- [ ] Pi-hole — DNS queries resolving
- [ ] Services — docker ps on all VMs shows expected containers
- [ ] DHCP clients — got new IPs from new DHCP server
- [ ] Backups — next scheduled vzdump completes successfully

---

## Device-Specific Re-IP Procedures

### PVE Host (Proxmox)

**Config:** `/etc/network/interfaces`

```bash
# Edit (pre-stage, don't apply yet)
ssh pve "cp /etc/network/interfaces /etc/network/interfaces.bak"
# Apply requires reboot or `ifreload -a` (risky on remote)
ssh pve "reboot"
```

**Verify:**
```bash
ssh pve "ip addr show vmbr0"
ssh pve "ip route"
```

### Ubuntu 24.04 VMs (netplan)

**Config:** `/etc/netplan/50-cloud-init.yaml`

```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses: [192.168.1.X/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [192.168.1.204]
```

**Apply:**
```bash
ssh <vm> "sudo netplan apply"
```

**Verify:**
```bash
ssh <vm> "ip addr show ens18"
ssh <vm> "ip route"
ssh <vm> "dig google.com"
```

### Dell N2024P Switch

**Method 1 — Web UI** (if reachable):
- Navigate to `http://<current-ip>`
- System > Management Interface > IP Address
- Change IP, subnet, gateway
- Save

**Method 2 — Console cable:**
```
enable
configure
interface vlan 1
ip address 192.168.1.2 255.255.255.0
exit
ip default-gateway 192.168.1.1
exit
write memory
```

**Note:** Switch works as unmanaged L2 even without management IP. Re-IP can happen later.

### iDRAC (R730XD)

**Method 1 — ipmitool from pve:**
```bash
ssh pve "ipmitool -I lanplus -H <current-ip> -U root -P '<pass>' \
  lan set 1 ipaddr 192.168.1.250"
ssh pve "ipmitool -I lanplus -H <current-ip> -U root -P '<pass>' \
  lan set 1 netmask 255.255.255.0"
ssh pve "ipmitool -I lanplus -H <current-ip> -U root -P '<pass>' \
  lan set 1 defgw ipaddr 192.168.1.1"
```

**Method 2 — iDRAC web UI** (if reachable)

**Credentials:** Infisical `infrastructure/prod:/spine/shop/idrac/*`

### NVR (Hikvision)

**Method 1 — ISAPI PUT from pve:**
```bash
ssh pve "curl --digest -u '<user>:<pass>' -X PUT \
  'http://<current-ip>/ISAPI/System/Network/interfaces/1' \
  -d '<NetworkInterface><IPAddress><ipVersion>v4</ipVersion>\
  <addressingType>static</addressingType>\
  <ipAddress>192.168.1.216</ipAddress>\
  <subnetMask>255.255.255.0</subnetMask>\
  <DefaultGateway><ipAddress>192.168.1.1</ipAddress></DefaultGateway>\
  </IPAddress></NetworkInterface>'"
```

**Method 2 — NVR web UI** (if reachable)

**Credentials:** Infisical `infrastructure/prod:/spine/shop/nvr/*`

### WiFi AP (TP-Link EAP225)

**Method:** Web UI at current management IP. Change IP under Network > LAN.

**Note:** AP may also accept DHCP — if UDR6 has a DHCP reservation, AP could auto-accept the new IP on reboot.

**Normalization:** Follow `docs/governance/SHOP_NETWORK_NORMALIZATION.md` for the target IP structure and the rule that changes must be receipt-backed + SSOT-updated.

**Onboarding:** For new APs (or post-factory-reset), follow `docs/governance/SHOP_NETWORK_DEVICE_ONBOARDING.md` so identity/IP/credentials/doc updates happen consistently and are enforced by `network.shop.audit.status` + drift gate D54.

### Tailscale Subnet Route

```bash
ssh pve "tailscale set --advertise-routes=192.168.1.0/24"
```

**Verify:**
```bash
tailscale status  # from macbook — check pve shows new subnet
```

### NFS Exports (pve)

**Config:** `/etc/exports`

```bash
ssh pve "cp /etc/exports /etc/exports.bak"
# Edit to use new LAN IPs
ssh pve "exportfs -ra"  # reload without restart
```

**Verify:**
```bash
ssh pve "exportfs -v"
```

### NFS Client fstab (VMs)

**Config:** `/etc/fstab`

```
192.168.1.184:/tank/docker/download-stack  /opt/appdata  nfs  defaults,x-systemd.requires=network-online.target  0  0
192.168.1.184:/media                       /media        nfs  defaults,x-systemd.requires=network-online.target  0  0
```

**Critical:** Always unmount NFS BEFORE changing IPs to avoid D-state deadlock:
```bash
ssh <vm> "sudo umount -l /media /opt/appdata"
# ... change IPs ...
ssh <vm> "sudo mount -a"
```

---

## NFS Safety Rules

1. **NEVER use Tailscale IPs for NFS** — hard mount + Tailscale flap = D-state deadlock
2. **Always use LAN IPs** — pve LAN: 192.168.1.184
3. **Unmount before IP change** — `umount -l` (lazy) prevents D-state
4. **fstab must use** `x-systemd.requires=network-online.target`
5. **Test write after mount** — `touch /media/.test && rm /media/.test`

---

## 9. Change Pack Process

Every network cutover loop MUST have a companion **change pack** — a filled copy of
`docs/governance/CHANGE_PACK_TEMPLATE.md` placed alongside the loop scope file.

### How to create a change pack

1. Copy `docs/governance/CHANGE_PACK_TEMPLATE.md` to
   `mailroom/state/loop-scopes/<LOOP-ID>.changepack.md`
2. Fill every section (IP map, rollback map, preflight matrix, execution steps, etc.)
3. Execution steps MUST follow the ordering in `ops/bindings/cutover.sequencing.yaml`
4. Run `./bin/ops cap run network.cutover.preflight` — must emit GO before P2

### Sequencing rules

Cutover phases execute in mandatory order (from `cutover.sequencing.yaml`):

1. **Remote management** — Tailscale overlay stable
2. **Hypervisor** — PVE reachable on new subnet
3. **Switch** — management IP re-IPed
4. **LAN-only devices** — iDRAC, NVR, AP re-IPed
5. **Workloads** — NFS remount, Docker restart, service health

Devices may be deferred ONLY if they don't block workloads and deferral is documented
in the change pack's Deferred Items section with a follow-up loop reference.

### LAN-only devices

Devices with `access_method: lan_only` in `ssh.targets.yaml` cannot be reached via
Tailscale. Their status is checked by `network.lan.device.status` (ping via
`probe_via` host, not SSH). See NETWORK_RUNBOOK.md device-specific procedures for
re-IP commands.

### Enforcement

D53 (change-pack-integrity-lock) validates:
- `CHANGE_PACK_TEMPLATE.md` exists
- `cutover.sequencing.yaml` exists
- Every open cutover loop has a companion `.changepack.md`
- Companion files contain required sections

---

## Change History

| Date | Change | Loop |
|------|--------|------|
| 2026-02-09 | Shop LAN re-IP: legacy subnet → 192.168.1.0/24 (UDR6 deployment) | LOOP-UDR6-SHOP-CUTOVER-20260209 |
