---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: hass-operational-runbook
parent_loop: LOOP-HASS-SSOT-AUTOGRADE-20260210
migrated_from: "legacy home-assistant/ pillar (7 sources consolidated)"
---

# Home Assistant Operational Runbook

> Spine-native operational knowledge for the Home Assistant instance on proxmox-home.
> Infrastructure baseline: see `MINILAB_SSOT.md` (VM 100 section).
> Backup strategy: see `HOME_BACKUP_STRATEGY.md`.

---

## Spine Execution Protocol

All operations in this runbook MUST be executed via capability system:
- Execute: `./bin/ops cap run <capability>`
- Receipts: auto-generated per execution
- Direct execution of scripts is prohibited

---

## 1. Quick Reference

| Resource | Value |
|----------|-------|
| **VM** | 100 on proxmox-home (Beelink, HAOS) |
| **LAN IP** | 10.0.0.100 |
| **Tailscale IP** | 100.67.120.1 |
| **Web UI** | http://100.67.120.1:8123 or https://ha.ronny.works |
| **SSH** | `ssh hassio@ha` (Advanced SSH & Web Terminal add-on) |
| **API Token** | Infisical: `home-assistant/prod/HA_API_TOKEN` (Long-Lived Access Token) |
| **SSH Key** | Infisical: `home-assistant/prod/HA_SSH_KEY` |
| **Infisical Project** | `home-assistant` (ID: 5df75515-7259-4c14-98b8-5adda379aade) |

### API vs Supervisor Access

| Scope | Endpoint | Auth | Use Case |
|-------|----------|------|----------|
| **Core API** | `/api/*` | `HA_API_TOKEN` (Long-Lived) | Entities, services, states, history |
| **Supervisor API** | `/api/hassio/*` | Internal `SUPERVISOR_TOKEN` (injected into add-ons) | Add-on management, OS updates |

External tokens cannot access the Supervisor API. Add-on management requires the `ha` CLI inside the SSH container with Protection Mode **disabled**.

---

## 2. Integration Inventory

> Source: HA API `/api/config/config_entries/entry` (last extracted 2026-01-20)
> Policy: tracked via API extraction, not manual. `ha.ssot.propose` will automate.

### Active Integrations (Key Entries)

| Domain | Name/Title | Category |
|--------|-----------|----------|
| mqtt | Mosquitto broker | Infrastructure |
| hassio | Supervisor | Infrastructure |
| hacs | HACS | Infrastructure |
| backup | Backup | Infrastructure |
| go2rtc | go2rtc | Infrastructure |
| tplink | EMPRESS LAMP EP25, KING LAMP EP25 | Smart Home |
| august | Yale Assure Lock | Smart Home |
| ring | Doorbell + cameras | Smart Home |
| winix | Winix Purifier | Smart Home |
| sonoff | eWeLink devices | Smart Home |
| tuya | Cloud Tuya (x2) | Smart Home |
| roborock | Vacuum | Smart Home |
| apple_tv | Living Room (x2) | Media |
| webostv | LG Living Room, LG Guest Room | Media |
| androidtv_remote | Sony Bedroom TV | Media |
| braviatv | KD-65X80CK | Media |
| cast | Google Cast | Media |
| mobile_app | 4 devices (Ronny, Empress, Boca, Marium) | Companion |
| islamic_prayer_times | Prayer Times (x2) | Utility |
| met | Weather (Home) | Utility |
| caldav | iCloud calendars (ronny@hantash.com) | Utility |
| matter | Matter | Protocol |
| smlight | SLZB-06MU | Protocol |
| radarr, sonarr, lidarr | Media management | Media Mgmt |
| jellyfin | Media server | Media Mgmt |
| sabnzbd | Download clients (x2) | Media Mgmt |

**Total:** ~60 config entries across ~30 domains.

---

## 3. Automation Inventory

> 14 automations active. Critical fix: all button triggers include `not_from: ["unavailable", "unknown"]`.

| Automation | Entity Trigger | Action | Notes |
|-----------|---------------|--------|-------|
| Bedroom: King Button | `event.0x00158d008b875d40_action` (single) | `switch.toggle` king lamp | Zigbee button |
| Bedroom: Empress Button | `event.0xd44867fffe00c96f_action` (single) | `switch.toggle` empress lamp | Zigbee button |
| Office: Button | `event.0xa4c138cdbd2d0012_action` (single) | `light.toggle` office desk bulb | Zigbee button |
| Scene Switch: Btn 1-4 | `event.0xa4c138615058086b_action` (1-4_single) | Toggle empress/king/office/guest | 4-button scene switch |
| Mailbox: Vibration | `binary_sensor.vibration_sensor_vibration` on | Notify Ronny iPhone | Contact sensor |
| Zigbee: Low Battery | numeric_state < 20% on 6 sensors | Notify Ronny iPhone | Health monitoring |
| Zigbee: Stale Device Alert | time 09:00 daily | Notify if button silent > 12h | Health monitoring |
| System: Auto-Dismiss Login | event: persistent_notification from 127.0.0.1 | Dismiss notification | Noise suppression |
| Chores: Weekly Laundry | time 09:00 Sunday | Notify overdue laundry items | Chore tracker |
| Chores: Quarterly Maintenance | time 10:00 1st of month | Notify overdue HVAC/filter | Chore tracker |
| Chores: Daily Streak | time 00:01 daily | Increment/reset streak counter | Gamification |

### Critical Fix History

The `not_from: ["unavailable", "unknown"]` guard on all button triggers was **added and accidentally removed 3 times** before being made permanent. Without it, lights toggle on every HA restart when Zigbee2MQTT reconnects and entities transition from `unavailable` to their real state.

**Rule: never remove this guard from button automation triggers.**

---

## 4. Helper / Input Entity Inventory

| Entity ID | Type | Purpose |
|-----------|------|---------|
| `input_boolean.sd_focus_mode` | Boolean | Stream Deck focus mode signal |
| `input_boolean.sd_recording_mode` | Boolean | Stream Deck recording mode |
| `input_select.house_mode` | Select | House mode (Home/Sleep/Party) |
| `input_datetime.laundry_bathroom_towels` | Date | Last washed: bathroom towels |
| `input_datetime.laundry_bed_sheets_master` | Date | Last washed: master sheets |
| `input_datetime.laundry_bed_sheets_guest` | Date | Last washed: guest sheets |
| `input_datetime.laundry_kitchen_towels` | Date | Last washed: kitchen towels |
| `input_datetime.chore_hvac_filter` | Date | Last changed: HVAC filter |
| `input_datetime.chore_purifier_filters` | Date | Last changed: purifier filters |
| `counter.chore_streak` | Counter | Consecutive days with a chore completed |

---

## 5. HACS Inventory

### Custom Integrations (12)

| Component | Purpose |
|-----------|---------|
| `browser_mod` | Browser control + popups |
| `hacs` | HACS itself |
| `magic_areas` | Auto presence/lighting by area |
| `sonoff` | Sonoff/eWeLink device control |
| `winix` | Winix air purifier control |
| `webrtc` | WebRTC camera streaming |
| `ble_monitor` | BLE device monitoring |
| `dwains_dashboard` | Auto-dashboard framework |
| `fontawesome` | FontAwesome icons |
| `material_symbols` | Material icons |
| `mqtt_media_player` | MQTT-based media player |
| `ui_lovelace_minimalist` | Minimalist UI framework |

### Lovelace Cards (35)

**Core:** `button-card`, `lovelace-mushroom`, `lovelace-card-mod`, `lovelace-layout-card`, `lovelace-auto-entities`, `lovelace-card-tools`

**Media:** `mini-media-player`, `yet-another-media-player`, `upcoming-media-card`

**Weather/Calendar:** `clock-weather-card`, `platinum-weather-card`, `simple-weather-card`, `atomic-calendar-revive`, `calendar-card-pro`

**Controls:** `lovelace-big-slider-card`, `slider-button-card`, `lovelace-slider-entity-row`, `lovelace-mushroom-better-sliders`, `light-entity-card`

**UI:** `Bubble-Card`, `Ultra-Card`, `custom-sidebar`, `lovelace-navbar-card`, `status-card`, `custom-card-features`

**Utilities:** `mini-graph-card`, `timer-bar-card`, `scheduler-card`, `raptor-todo-hub-card`, `homeassistant-browser-control-card`, `mushroom-strategy`

**Icons:** `custom-brand-icons`, `hass-hue-icons`

---

## 6. Radio Coordinator Details

> Infrastructure IPs/models in MINILAB_SSOT. This section adds firmware/MAC/mode detail.

### SLZB-06 (Primary Zigbee Coordinator)

| Field | Value |
|-------|-------|
| Web UI | http://10.0.0.51 |
| Zigbee Socket | `tcp://10.0.0.51:6638` |
| MAC | 20:43:A8:51:15:E3 |
| Firmware (Core) | v3.1.6.dev |
| Firmware (Radio) | 20240710 (CC2652P) |
| HA Integration | Zigbee2MQTT (configure socket in Z2M add-on settings) |
| Mode | Ethernet ON, USB OFF, Zigbee Coordinator ON |

### SLZB-06MU (Matter-Capable Coordinator)

| Field | Value |
|-------|-------|
| Web UI | http://10.0.0.52 |
| Zigbee Socket | `tcp://10.0.0.52:6638` (not used for Zigbee) |
| MAC | 82:B5:4E:97:B0:28 |
| Firmware | MultiPAN/RCP (flashed 2026-01-11) |
| HA Integration | Planned: OpenThread Border Router |

### TubesZB Z-Wave PoE

| Field | Value |
|-------|-------|
| Module | Zooz ZAC93 (800 Series Long Range) |
| Socket | `tcp://<IP>:6638` (IP TBD) |
| HA Integration | Z-Wave JS UI Add-on |
| Status | On hand, not installed |

### Configuration Rules

- Both coordinators have **static IPs** (not DHCP)
- Do NOT run two Zigbee coordinators simultaneously (creates separate networks)
- Use SLZB-06 for Zigbee, SLZB-06MU for Matter/Thread

---

## 7. Backup & Restore Procedure

### App-Level Backup (HA Built-In)

**Method:** HA CLI via SSH add-on creates a full backup (config + add-ons + DB).

```
ssh hassio@ha "bash -l -c 'ha backups new --name ha-backup-YYYYMMDD'"
```

**Artifacts:** `/backup/*.tar` on HA VM, synced to NAS `/volume1/backups/homeassistant_backups/`.

**Retention:** Keep last 3 on HA, 7 days locally, 4 syncs on NAS.

### Offsite Sync

**Architecture:** HA (SSH add-on) -> MacBook (staging at `/tmp/ha-backup-staging`) -> Synology NAS.

**Schedule:** Weekly Sunday 04:30 via macOS launchd (`com.ronny.ha-offsite-sync`).

**Steps:**
1. SSH to HA, list `/backup/*.tar`
2. rsync pull to local staging
3. rsync push to `nas:/volume1/backups/apps/home-assistant/`
4. Create sync receipt on NAS
5. Prune old receipts (keep last 4)

### VM-Level Backup

**Method:** Proxmox vzdump (P0 tier, daily 03:00) to NAS via NFS.
**See:** `HOME_BACKUP_STRATEGY.md` for schedule and retention.

### Restore Procedure

1. **VM restore:** `qmrestore` from vzdump artifact on NAS
2. **App restore:** HA Settings > System > Backups > select backup > Restore
3. **Post-restore:** Verify Zigbee2MQTT reconnects, check automation states, validate calendar integration

---

## 8. Recovery Runbooks

### Zigbee IP Change Recovery

If the SLZB-06 coordinator changes IP and Zigbee2MQTT fails to connect:

**Symptom:** Z2M logs show `Opening TCP socket with <OLD_IP>`.

**Root cause:** The Z2M add-on persists config in an internal `options.json` that overrides `configuration.yaml`.

**Fix (docker injection):**
1. SSH to HA: `ssh hassio@ha`
2. Copy config out: `sudo docker cp addon_45df7312_zigbee2mqtt:/data/options.json /tmp/options.json`
3. Edit: `sudo sed -i 's/<OLD_IP>/<NEW_IP>/g' /tmp/options.json`
4. Copy back: `sudo docker cp /tmp/options.json addon_45df7312_zigbee2mqtt:/data/options.json`
5. Restart: `sudo docker restart addon_45df7312_zigbee2mqtt`
6. Verify: `sudo docker logs addon_45df7312_zigbee2mqtt --tail 100 | grep "Connected to MQTT"`

**Alternative:** Settings > Add-ons > Zigbee2MQTT > Configuration > type full `tcp://IP:6638` in port field > Save.

### SLZB-06 Mode Configuration

If the add-on connects but Zigbee devices are unreachable:
1. Open SLZB-06 Web UI (http://10.0.0.51)
2. Mode tab: Ethernet ON, USB OFF
3. Mode tab: Zigbee Coordinator ON
4. Settings: TCP Port must be **6638** (not 6053)

### CalDAV/iCloud Calendar Recovery

If calendars disappear after HA rebuild or credential rotation:

1. **Retrieve credentials from Infisical:**
   - Apple ID: `ronny@hantash.com`
   - App-specific password: Infisical `infrastructure/prod/APPLE_APP_PASSWORD`

2. **If password revoked, regenerate:**
   - https://appleid.apple.com > Sign-In and Security > App-Specific Passwords
   - Generate new, name: `Home Assistant`
   - Update Infisical

3. **Add CalDAV integration:**
   - Settings > Devices & Services > Add Integration > CalDAV
   - URL: `https://caldav.icloud.com`
   - Username: `ronny@hantash.com`
   - Password: from Infisical

4. **Verify entities:** `calendar.lilbabymarium_n_ronron`, `calendar.work`

5. **HACS dependencies needed:** `calendar-card-pro`, `atomic-calendar-revive`, `card-mod`

### Tailscale Userspace Networking Fix

If HA cannot reach other Tailnet nodes (no `tailscale0` interface):

**Root cause:** UI/YAML config for `userspace_networking` fails to persist.

**Fix:** Force via Supervisor API:
```bash
docker exec hassio_cli curl -X POST \
  -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"options": {"userspace_networking": false, "accept_routes": true, "accept_dns": true}}' \
  http://supervisor/addons/a0d7b954_tailscale/options
```
Then restart the Tailscale add-on. Verify: `ip link | grep tailscale0`.

---

## 9. Known Fixes & Gotchas

| Issue | Fix | Reference |
|-------|-----|-----------|
| Lights toggle on HA restart | `not_from: ["unavailable", "unknown"]` on all button triggers | automations.yaml (added 3x, do not remove) |
| Token shell parsing errors | Cache to `/tmp/ha_token_clean.txt`; use `$(cat /tmp/ha_token_clean.txt)` | Token contains special chars |
| "Login attempt failed" spam | Auto-dismiss automation for 127.0.0.1 sources | System automation |
| SSH `ha info` returns 401 | Protection Mode must be OFF on SSH add-on; reinstall if token corrupt | Add-on config |
| Z2M `options.json` override | Edit via docker cp, not YAML file | See Zigbee recovery above |
| `ip_ban_enabled` | Must stay in `configuration.yaml` http section; threshold=5 | Security |

---

## 10. API Field Mapping for `ha.ssot.propose`

The P1 capability must fetch these endpoints and produce a structured diff:

| Endpoint | Fields Needed | Maps To |
|----------|--------------|---------|
| `GET /api/config/config_entries/entry` | domain, title, state | Section 2 (Integration Inventory) |
| `GET /api/states` filter `automation.*` | entity_id, state, attributes.last_triggered, attributes.friendly_name | Section 3 (Automation Inventory) |
| `GET /api/states` filter `input_*` | entity_id, state, attributes.friendly_name | Section 4 (Helper Inventory) |
| `GET /api/states` grouped by domain | count per domain, unavailable count | Summary statistics |
| Supervisor: `GET /addons` (if accessible) | name, state, version | Add-on health (optional) |

**Output format:** YAML diff patch against this runbook's inventory sections.

**Determinism rule:** Sort all lists by entity_id/domain alphabetically.
