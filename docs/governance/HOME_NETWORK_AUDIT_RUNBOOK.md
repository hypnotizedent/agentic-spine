---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: home-network
---

# Home Network Audit Runbook (Canonical)

> One command to detect every kind of home network drift: SSOT parity, live truth mismatches, and doc staleness.

## Spine Execution Protocol

All operations in this runbook MUST be executed via capability system:
- Execute: `./bin/ops cap run <capability>`
- Receipts: auto-generated per execution
- Direct execution of scripts is prohibited

---

## Capabilities

| Capability | Safety | Purpose |
|------------|--------|---------|
| `home.vm.status` | read-only | Check VM/LXC running state on proxmox-home |
| `home.health.check` | read-only | HTTP health probes for home services |
| `home.backup.status` | read-only | Check backup artifact freshness |
| `network.home.dhcp.audit` | read-only | Cross-reference UniFi DHCP reservations against device registry |
| `network.home.unifi.clients.snapshot` | read-only | Snapshot connected UniFi clients (MAC/IP/name) |
| `ha.z2m.devices.snapshot` | read-only | Extract Z2M device registry to `ops/bindings/z2m.devices.yaml` |
| `ha.addons.snapshot` | read-only | Extract HA Supervisor add-on inventory to `ops/bindings/ha.addons.yaml` |
| `ha.config.extract` | read-only | Extract HA config files to workbench |

## DHCP Reservation Audit

```bash
./bin/ops cap run network.home.dhcp.audit
```

Queries UDR7 via API key, cross-references against `ops/bindings/home.device.registry.yaml`.
Reports: OK (reserved + matches), FAIL (missing reservation for infra/IoT), INFO (personal/dynamic).

**API method to create reservations** (requires `UNIFI_HOME_API_KEY` in Infisical):
```bash
curl -sk -X PUT "https://10.0.0.1/proxy/network/api/s/default/rest/user/{USER_ID}" \
  -H "X-API-KEY: $UNIFI_HOME_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"use_fixedip": true, "fixed_ip": "10.0.0.X"}'
```

## Drift Gates

| Gate | Name | What It Checks |
|------|------|---------------|
| D92 | ha-config-version-control | HA config files exist in workbench |
| D98 | z2m-device-parity | Z2M device binding exists + fresh |
| D99 | ha-token-freshness | HA API token returns HTTP 200 |
| D100 | vm-ip-parity-lock | VM LAN IPs match across SSOTs |
| D101 | ha-addon-inventory-parity | HA add-on binding exists + fresh |

## Credentials

| Key | Infisical Path | Purpose |
|-----|---------------|---------|
| UNIFI_HOME_USER | home-assistant/prod | UDR7 cookie auth (read-only) |
| UNIFI_HOME_PASSWORD | home-assistant/prod | UDR7 cookie auth (read-only) |
| UNIFI_HOME_API_KEY | home-assistant/prod | UDR7 API key (read/write, never expires) |
| HA_API_TOKEN | home-assistant/prod | Home Assistant REST API |

## Connectivity Checks

### Core Devices

```bash
# Gateway
ping -c1 10.0.0.1

# NAS (LAN)
ping -c1 10.0.0.150

# proxmox-home (Tailscale)
ping -c1 100.103.99.62
```

### VMs/LXCs (Tailscale)

```bash
# Home Assistant
curl -s -o /dev/null -w "%{http_code}" http://100.67.120.1:8123/api/
# Expected: 401 (auth required = healthy)

# Vaultwarden
curl -s -o /dev/null -w "%{http_code}" http://100.93.142.63:8080/
# Expected: 200

# Pi-hole (if running)
ssh pihole-home "pihole status"

# download-home (if running)
ssh download-home uptime
```

### IoT Coordinators (LAN-only, probe via proxmox-home)

```bash
ssh root@proxmox-home "ping -c1 10.0.0.51"   # SLZB-06
ssh root@proxmox-home "ping -c1 10.0.0.52"   # SLZB-06MU
ssh root@proxmox-home "ping -c1 10.0.0.90"   # TubesZB
```

## Backup Verification

### Proxmox vzdump Status

```bash
./bin/ops cap run home.backup.status
```

**Expected targets:**
- P0 (daily 03:00): VMs 100, 102
- P1 (daily 03:15): LXC 103
- P2 (weekly Sun 04:00): VM 101, LXC 105

### NAS Storage Health

```bash
ssh ronadmin@nas "cat /proc/mdstat"   # RAID array status
ssh ronadmin@nas "df -h | grep volume1"  # Storage utilization
```

### NFS Mount Verification

```bash
ssh root@proxmox-home "mount | grep nfs"
```

**Expected:**
- `10.0.0.150:/volume1/homelab` on `/mnt/pve/synology918`
- `10.0.0.150:/volume1/backups/proxmox_backups` on `/mnt/pve/synology-backups`

## VM/LXC Status

```bash
./bin/ops cap run home.vm.status
```

**Expected state:**
- VM 100 (homeassistant): running
- VM 101 (immich): stopped
- VM 102 (vaultwarden): running
- LXC 103 (download-home): stopped
- LXC 105 (pihole-home): stopped

## UDR7 Gateway Health

```bash
# Web UI
curl -s -o /dev/null -w "%{http_code}" http://10.0.0.1
# Expected: 200

# DNS resolution
dig @10.0.0.1 google.com +short

# Ping latency
ping -c5 10.0.0.1
```

## Tailscale Node Status

```bash
tailscale status | grep -E "(proxmox-home|nas|ha|vault|pihole-home|download-home)"
```

**Expected home nodes:**
- proxmox-home (100.103.99.62)
- nas (100.102.199.111)
- ha (100.67.120.1)
- vault (100.93.142.63)

## Drift Interpretation

| Finding | Action |
|---------|--------|
| `UNREACHABLE` | Device offline or IP changed — check UDR7 DHCP leases |
| `BINDING != SSOT` | Update whichever is stale |
| `BACKUP STALE` | Check vzdump job logs on proxmox-home |
| `NFS UNMOUNTED` | Remount or check NAS reachability |

## Related Documents

- [HOME_NETWORK_DEVICE_ONBOARDING.md](HOME_NETWORK_DEVICE_ONBOARDING.md)
- [MINILAB_SSOT.md](MINILAB_SSOT.md)
- [HOME_BACKUP_STRATEGY.md](HOME_BACKUP_STRATEGY.md)
- [SHOP_NETWORK_AUDIT_RUNBOOK.md](SHOP_NETWORK_AUDIT_RUNBOOK.md)
