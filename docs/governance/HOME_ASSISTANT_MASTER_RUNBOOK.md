---
status: authoritative
owner: "@ronny"
created: "2026-03-03"
last_verified: "2026-03-03"
scope: ha-master-runbook
parent_loop: LOOP-HA-E2E-CLEANUP-WAVE-20260303
merges:
  - HASS_OPERATIONAL_RUNBOOK.md
  - HASS_AGENT_GOTCHAS.md
  - HASS_MCP_INTEGRATION.md
  - HASS_SSOT_BASELINE.md
  - HASS_LEGACY_EXTRACTION_MATRIX.md
---

# Home Assistant Master Runbook

> Single canonical operator reference for HA governance.
> Surface index: `docs/governance/HOME_ASSISTANT_SURFACE_INDEX.yaml`
> Reliability contract: `docs/governance/HOME_ASSISTANT_RELIABILITY_CONTRACT.yaml`
> All operations MUST execute via capability system: `./bin/ops cap run <capability>`

---

## S1. Quick Reference

| Resource | Value |
|----------|-------|
| **VM** | 100 on proxmox-home (Beelink EQ12, HAOS) |
| **LAN IP** | 10.0.0.100 |
| **Web UI** | http://10.0.0.100:8123 (LAN) / https://ha.ronny.works (external) |
| **SSH** | `ssh hassio@ha` (Advanced SSH add-on, Protection Mode OFF) |
| **API Token** | Infisical: `home-assistant/prod/HA_API_TOKEN` |
| **SSH Key** | Infisical: `home-assistant/prod/HA_SSH_KEY` |
| **Infisical Project** | `home-assistant` (ID: 5df75515-7259-4c14-98b8-5adda379aade) |

### Site Separation Model

| Site | HA Instance | Access | Governance |
|------|------------|--------|------------|
| **Home** | VM 100 (proxmox-home) | LAN only (10.0.0.0/24) | This runbook |
| **Shop** | None (shop has no HA) | N/A | N/A |

Governance is unified in spine. Runtime is home-only. Shop infrastructure uses separate domain contracts (media, finance, infra-core).

### API Scope

| Scope | Endpoint | Auth |
|-------|----------|------|
| **Core API** | `/api/*` | `HA_API_TOKEN` (Long-Lived) |
| **Supervisor API** | `/api/hassio/*` | Internal `SUPERVISOR_TOKEN` (add-on injected) |

External tokens cannot access Supervisor API. Add-on management requires `ha` CLI inside SSH container.

---

## S2. Identity Model

### Naming Convention

Pattern: `{area}_{function}_{qualifier}` (snake_case)

Authority: `ops/bindings/ha.naming.convention.yaml`

Examples: `bedroom_purifier`, `office_button`, `bedroom_bulb_king`

### Identity Chain

```
home.device.registry.yaml (intended identity)
  → ha.device.map.yaml (runtime cross-reference)
    → ha.ssot.baseline.yaml (drift baseline)
      → drift gates D117, D120 (enforcement)
```

### Reconciliation Rules

1. `home.device.registry.yaml` is source-of-truth for intended identity
2. `ha.device.map.yaml` reconciles runtime identifiers to registry intent
3. Divergence generates a governed gap before further mutation
4. Post-mutation: run `ha.device.map.build` → `ha.refresh` → `ha.ssot.baseline.build`

---

## S3. Device Inventory

### Zigbee Devices (5 active via SLZB-06 coordinator)

| Friendly Name | IEEE | Model | Manufacturer | Power |
|--------------|------|-------|-------------|-------|
| bedroom_empress_button | 0xd44867fffe00c96f | SNZB-01P | eWeLink | Battery |
| bedroom_king_button | 0x00158d008b875d40 | lumi.remote.b1acn01 | LUMI/Aqara | Battery |
| front_door_sensor | 0x00158d008b85aa18 | lumi.sensor_magnet.aq2 | LUMI/Aqara | Battery |
| laundry_washer_vibration | 0x00158d008b7d6934 | lumi.vibration.aq1 | LUMI/Aqara | Battery |
| office_button | 0xa4c138cdbd2d0012 | TS0041 | Tuya (_TZ3000) | Battery |

### Matter/Thread Devices (2 active via SLZB-06MU OTBR)

| Device | Entity Pattern | Protocol |
|--------|---------------|----------|
| BILRESA dual button | `event.bilresa_dual_button_*` | Matter/Thread |
| MYGGSPRAY motion sensor | `binary_sensor.myggspray_*` | Matter/Thread |

### WiFi/Cloud Devices

Tracked in `home.device.registry.yaml`. Key entries: TP-Link EP25 plugs, Tuya bulbs, Winix purifier, Roborock vacuum, Ring doorbell, August lock, LG/Sony TVs, Apple TV, HomePod.

### Orphan Devices (145 classified)

All classified in `ha.orphan.classification.yaml`. Major categories: uptime-kuma-probe (47), proxmox-subsystem (41), media-device (10), nas-subsystem (11). No action required unless "needs-registry" category appears.

---

## S4. SSOT Architecture

### Two-Tier Baseline

| Tier | Binding | Purpose | Freshness Gate |
|------|---------|---------|---------------|
| **Runtime baseline** | `ha.ssot.baseline.yaml` | Full entity/device state | D115 (7 days) |
| **Snapshot layer** | `ha.addons.yaml`, `ha.automations.yaml`, etc. | Domain-specific snapshots | D101/D102 (14 days) |

### Refresh Commands

```bash
# Full refresh (all 12 snapshot surfaces + SSOT baseline)
./bin/ops cap run ha.refresh

# Individual snapshots
./bin/ops cap run ha.addons.snapshot
./bin/ops cap run ha.automations.snapshot
./bin/ops cap run ha.device.map.build
./bin/ops cap run ha.ssot.baseline.build
```

### Required SSOT Surfaces for Mutation Approval

- `ops/bindings/ha.areas.yaml` (D120 enforces parity)
- `ops/bindings/ha.orphan.classification.yaml`
- `ops/bindings/home.device.registry.yaml`
- `ops/bindings/ha.ssot.baseline.yaml` (D115 enforces freshness)

---

## S5. MCP Integration

### Governance Boundary

HA MCP server provides 4 tools: `ha_get_states`, `ha_get_state`, `ha_call_service`, `ha_get_history`.

**D105 gate enforces:** `ha_call_service` is blocked in MCP config (read-only boundary). All mutations flow through spine capabilities.

### MCP Server Location

Workbench: `infra/compose/mcpjungle/servers/home-assistant/`

### Parity Check

D66 gate enforces parity between workbench canonical and MCPJungle mirror (SHA256 compare).

---

## S6. Radio Coordinators

### Primary Zigbee: SLZB-06

| Field | Value |
|-------|-------|
| Web UI | http://10.0.0.51 |
| Socket | tcp://10.0.0.51:6638 |
| Firmware (Core) | v3.1.6.dev |
| Firmware (Radio) | 20240710 (CC2652P) |
| Integration | Zigbee2MQTT |
| Mode | Ethernet ON, USB OFF, Coordinator ON |

### Matter/Thread: SLZB-06MU

| Field | Value |
|-------|-------|
| Web UI | http://10.0.0.52 |
| Socket | tcp://10.0.0.52:6638 |
| Firmware (Core) | v3.2.4 |
| Radio Mode | Thread/RCP |
| Integration | OpenThread Border Router (OTBR) |

### Z-Wave: TubesZB PoE (ZAC93 800LR)

| Field | Value |
|-------|-------|
| IP | 10.0.0.90 |
| Socket | tcp://10.0.0.90:6638 |
| ESPHome FW | 2025.10.27.2 |
| Status | Connected, Z-Wave JS UI not yet started |

### Coordinator Rules

- All three have static IPs via DHCP reservation
- SLZB-06 for Zigbee ONLY, SLZB-06MU for Matter/Thread ONLY
- Never run two Zigbee coordinators simultaneously
- All PoE-powered via UniFi switch

---

## S7. Automation Summary

27 automations active. See `ops/bindings/ha.automations.yaml` for full YAML.

**Critical rule:** All button triggers include `not_from: ["unavailable", "unknown"]`. Without this, lights toggle on every HA restart when Z2M reconnects. This guard was accidentally removed 3 times before being made permanent.

Key automation groups:
- **Button→Light toggles** (bedroom empress/king, office, scene switch)
- **House mode** (Sleep all-off, Morning wake, Away security alert)
- **Chore tracking** (daily streak, laundry, maintenance reminders)
- **Health monitoring** (Z2M low battery alert, stale device alert)
- **System** (auto-dismiss localhost login failures)

---

## S8. Backup & Recovery

### Daily Backup

Proxmox vzdump captures VM 100 daily at 03:00 to NAS via NFS. App-level `/backup/*.tar` included in VM snapshot.

### Manual App Backup

```bash
ssh hassio@ha "bash -l -c 'ha backups new --name ha-backup-YYYYMMDD'"
```

### Recovery Options

| Scenario | RTO | Method |
|----------|-----|--------|
| Config corruption | ~10 min | App-level restore from `/backup/` |
| Add-on failure | ~15 min | App-level restore with add-ons |
| VM disk failure | ~30 min | vzdump restore + boot |
| Full host failure | ~1 hour | vzdump restore on alternate node |

### Post-Restore Checklist

1. HA web UI accessible at http://10.0.0.100:8123
2. Z2M reconnects to SLZB-06 (check add-on logs)
3. All 27 automations enabled
4. CalDAV calendar shows events
5. SSH add-on accessible
6. Run `ha.device.map.build` to verify entity count

---

## S9. Known Gotchas

| Issue | Fix | Reference |
|-------|-----|-----------|
| Lights toggle on HA restart | `not_from: ["unavailable", "unknown"]` on button triggers | S7 |
| Token shell parsing | Cache to `/tmp/ha_token_clean.txt` | Infisical fetch |
| "Login attempt failed" spam | Auto-dismiss automation for 127.0.0.1 | System automation |
| SSH `ha info` 401 | Protection Mode OFF on SSH add-on | Add-on config |
| Z2M `options.json` override | `docker cp` to edit, not YAML file | S10 recovery |
| Matter BLE commissioning | Use iPhone Companion App, not `matter/commission_on_network` | Thread sleepy devices |
| OTBR isolated network | Must share Apple Home Thread credentials first | S6 |
| Supervisor API from external | Not possible — use SSH + `ha` CLI | S1 API scope |

---

## S10. Recovery Runbooks

### Zigbee IP Change

If SLZB-06 changes IP:
1. SSH to HA
2. `sudo docker cp addon_45df7312_zigbee2mqtt:/data/options.json /tmp/options.json`
3. `sudo sed -i 's/OLD_IP/NEW_IP/g' /tmp/options.json`
4. `sudo docker cp /tmp/options.json addon_45df7312_zigbee2mqtt:/data/options.json`
5. `sudo docker restart addon_45df7312_zigbee2mqtt`

### CalDAV Recovery

1. Get Apple app-specific password from Infisical
2. Settings > Devices & Services > Add Integration > CalDAV
3. URL: `https://caldav.icloud.com`, user: `ronny@hantash.com`

### Thread Credential Sharing (Apple Home → HA)

1. iPhone Companion App → Settings → Thread → Configure (transfers credentials)
2. Disable OTBR → push Apple TLV dataset → enable OTBR
3. Verify OTBR state = "router" (not "leader" = isolated)
4. Restart Matter Server

### Tailscale Userspace Fix

Force via Supervisor API: set `userspace_networking: false`, `accept_routes: true`. Restart Tailscale add-on.

---

## S11. Maintenance Cadence

### Daily (automated via drift gates)

| Gate | What | Auto-fix |
|------|------|----------|
| D99 | Token freshness | Rotate in Infisical |
| D113 | Z2M bridge health | Check addon, power cycle SLZB-06 |
| D118 | Z2M battery/staleness | Replace battery |
| D114 | Automation count stable | Update expected count |

### Weekly Operator (5 minutes)

```bash
./bin/ops cap run ha.status
./bin/ops cap run ha.z2m.health
./bin/ops cap run ha.refresh    # if bindings >7 days old
```

### On Device Change

| Action | Commands |
|--------|----------|
| Add Zigbee device | Pair in Z2M → `ha.z2m.devices.snapshot` → add to `z2m.naming.yaml` → `ha.device.map.build` |
| Add Matter device | Commission via iPhone → `ha.device.map.build` |
| Add WiFi device | DHCP reservation → add to `home.device.registry.yaml` → `ha.device.map.build` |
| Rename device | `ha.device.rename` → update `z2m.naming.yaml` if Zigbee |
| Add automation | `ha.automation.create` → `ha.automations.snapshot` → update D114 count |

### Freshness Thresholds

| Binding | Max Age | Gate |
|---------|---------|------|
| `ha.ssot.baseline.yaml` | 7 days | D115 |
| `ha.addons.yaml` | 14 days | D101 |
| `ha.device.map.yaml` | 14 days | D102 |
| `z2m.devices.yaml` | 14 days | D98 |

---

## S12. Surface Map

For the complete surface classification (keep/merge/tombstone), see:

`docs/governance/HOME_ASSISTANT_SURFACE_INDEX.yaml`

For device reliability policy (buttons, Zigbee, OTBR, Aqara):

`docs/governance/HOME_ASSISTANT_RELIABILITY_CONTRACT.yaml`
