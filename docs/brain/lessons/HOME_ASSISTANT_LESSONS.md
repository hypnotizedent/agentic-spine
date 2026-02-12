---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: home-lessons
---

# Home Assistant Lessons

> Architectural lessons and operational gotchas for the HA instance on proxmox-home VM 100.
> Full runbook: see `HASS_OPERATIONAL_RUNBOOK.md`.

## Architecture

**Home Assistant OS is NOT a Docker Compose stack.** The Supervisor manages add-ons as containers. Use `ha addons` CLI, not docker-compose.

| Field | Value |
|-------|-------|
| VM ID | 100 on proxmox-home |
| Tailscale IP | 100.67.120.1 |
| Local IP | 10.0.0.102 |
| Web UI | http://ha:8123 |
| SSH | `ssh hassio@ha` |
| Resources | 2c / 4GB RAM / 32GB disk |
| OS | Home Assistant OS (Proxmox VM) |

## Radio Coordinators

| Device | Model | IP | Protocol | Status |
|--------|-------|----|----------|--------|
| SLZB-06 | SMLIGHT SLZB-06 | 10.0.0.51 | Zigbee (CC2652P) | Online |
| SLZB-06MU | SMLIGHT SLZB-06MU | 10.0.0.52 | Zigbee + Matter | Online (reserved) |
| TubesZB | TubesZB Z-Wave | 10.0.0.217 | Z-Wave 800 | On hand |

**Rules:**
1. Do NOT run two Zigbee coordinators simultaneously
2. SLZB-06 is production Zigbee; SLZB-06MU reserved for Matter/Thread
3. All coordinators have static IPs (not DHCP)
4. Test IP connectivity before troubleshooting Z2M config

## Key Integrations

Infrastructure (MQTT, Supervisor, HACS), Smart Home (TP-Link, August, Ring, Winix, Roborock), Media (Apple TV, LG webOS, Jellyfin), Protocol (Zigbee via Z2M, Matter), Companion (4 mobile devices).

**Critical dependency:** MQTT broker (Mosquitto add-on) must be running for Zigbee2MQTT.

## Backup Strategy

- **VM-level:** vzdump P0 daily 03:00 (artifact confirmed 2026-02-12, 8GB)
- **App-level:** HA built-in backup via `ha backups new`, synced to NAS weekly

## API Access

```bash
curl -H "Authorization: Bearer $HA_API_TOKEN" http://100.67.120.1:8123/api/states
```

Token in Infisical `home-assistant/prod/HA_API_TOKEN`. Returns 401 without auth (healthy signal).

**Supervisor API** requires `ha` CLI inside SSH container with Protection Mode OFF.

## Critical Fixes

### Lights Toggle on HA Restart
ALL button automation triggers MUST have `not_from: ["unavailable", "unknown"]`. Without this guard, lights toggle on every restart when entities transition from unavailable to real state.

### Zigbee IP Change Recovery
Z2M add-on persists config in internal `options.json` that overrides `configuration.yaml`. Fix via docker cp injection — see HASS_OPERATIONAL_RUNBOOK.md section 8.

### Tailscale Userspace Networking
UI config for `userspace_networking` fails to persist. Force via Supervisor API curl POST to `/addons/a0d7b954_tailscale/options`.

## Resource Constraints

Beelink has 27GB total RAM shared across all VMs. VM 100 gets 4GB. Do NOT run heavy ML workloads on HA.

## Related Documents

- `docs/governance/HASS_OPERATIONAL_RUNBOOK.md`
- `docs/governance/MINILAB_SSOT.md`
- `docs/governance/HOME_BACKUP_STRATEGY.md`
