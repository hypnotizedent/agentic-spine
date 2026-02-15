---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
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

> Source: HA API `/api/config/config_entries/entry` (last extracted 2026-02-15)
> Policy: tracked via API extraction, not manual. `ha.ssot.propose` will automate.

### Active Integrations (Key Entries)

| Domain | Name/Title | Category |
|--------|-----------|----------|
| androidtv_remote | Sony Bedroom TV | Media |
| apple_tv | Living Room, Office | Media |
| backup | Backup | Infrastructure |
| caldav | iCloud calendars (ronny@hantash.com) | Utility |
| esphome | tubeszb-2026-zw | Protocol |
| go2rtc | go2rtc | Infrastructure |
| google_translate | Google Translate TTS | Utility |
| group | all bulbs, all lamps, bedroom lamps | Infrastructure |
| hacs | HACS | Infrastructure |
| hassio | Supervisor | Infrastructure |
| islamic_prayer_times | Islamic Prayer Times | Utility |
| jellyfin | Media server | Media Mgmt |
| local_todo | shopping-list | Utility |
| matter | Matter | Protocol |
| met | Weather (Home) | Utility |
| mobile_app | Ronny, Empress, Boca (x2), Marium | Companion |
| mqtt | Mosquitto broker | Infrastructure |
| radarr, lidarr | Media management | Media Mgmt |
| radio_browser | Radio Browser | Media |
| ring | Doorbell + cameras | Smart Home |
| roborock | Vacuum | Smart Home |
| sabnzbd | Download clients (x2) | Media Mgmt |
| shopping_list | Shopping list | Utility |
| smlight | SLZB-06MU | Protocol |
| sonoff | eWeLink devices | Smart Home |
| sun | Sun | Utility |
| synology_dsm | DS918 | Infrastructure |
| thread | Thread | Protocol |
| tplink | EMPRESS LAMP EP25, KING LAMP EP25 | Smart Home |
| tuya | Cloud Tuya (x2) | Smart Home |
| webostv | LG Living Room, LG Guest Room | Media |
| webrtc | WebRTC Camera | Infrastructure |
| winix | Winix Purifier | Smart Home |

**Total:** ~47 config entries across ~34 domains.

---

## 3. Automation Inventory

> 14 automations active. Critical fix: all button triggers include `not_from: ["unavailable", "unknown"]`.

| Automation | Entity Trigger | Action | Notes |
|-----------|---------------|--------|-------|
| Bedroom: Empress Button → Plug | `event.0xd44867fffe00c96f_action` (single) | `switch.toggle` empress lamp | Zigbee button |
| Bedroom: King Button → Plug | `event.0x00158d008b875d40_action` (single) | `switch.toggle` king lamp | Zigbee button |
| Chores: Daily Streak Check | time 00:01 daily | Increment/reset streak counter | Gamification |
| Chores: Quarterly Maintenance Reminder | time 10:00 1st of month | Notify overdue HVAC/filter | Chore tracker |
| Chores: Weekly Laundry Reminder | time 09:00 Sunday | Notify overdue laundry items | Chore tracker |
| Living Room: Scene Btn 1 → Empress Lamp | `event.0xa4c138615058086b_action` (1_single) | `switch.toggle` empress lamp | Scene switch |
| Living Room: Scene Btn 2 → King Lamp | `event.0xa4c138615058086b_action` (2_single) | `switch.toggle` king lamp | Scene switch |
| Living Room: Scene Btn 3 → Office Bulb | `event.0xa4c138615058086b_action` (3_single) | `light.toggle` office desk bulb | Scene switch |
| Living Room: Scene Btn 4 → Guest Room Bulb | `event.0xa4c138615058086b_action` (4_single) | `light.toggle` guest room bulb | Scene switch |
| Mailbox: Vibration → Notify | `binary_sensor.vibration_sensor_vibration` on | Notify Ronny iPhone | Contact sensor |
| Office: Button → Desk Bulb | `event.0xa4c138cdbd2d0012_action` (single) | `light.toggle` office desk bulb | Zigbee button |
| System: Auto-Dismiss Localhost Login Failures | event: persistent_notification from 127.0.0.1 | Dismiss notification | Noise suppression |
| Zigbee: Low Battery Alert | numeric_state < 20% on 6 sensors | Notify Ronny iPhone | Health monitoring |
| Zigbee: Stale Device Alert (Daily) | time 09:00 daily | Notify if button silent > 12h | Health monitoring |

### Critical Fix History

The `not_from: ["unavailable", "unknown"]` guard on all button triggers was **added and accidentally removed 3 times** before being made permanent. Without it, lights toggle on every HA restart when Zigbee2MQTT reconnects and entities transition from `unavailable` to their real state.

**Rule: never remove this guard from button automation triggers.**

---

## 4. Helper / Input Entity Inventory

| Entity ID | Type | Purpose |
|-----------|------|---------|
| `counter.chore_streak` | Counter | Consecutive days with a chore completed |
| `input_boolean.sd_focus_mode` | Boolean | Stream Deck focus mode signal |
| `input_boolean.sd_recording_mode` | Boolean | Stream Deck recording mode |
| `input_datetime.chore_hvac_filter` | Date | Last changed: HVAC filter |
| `input_datetime.chore_purifier_filters` | Date | Last changed: purifier filters |
| `input_datetime.laundry_bathroom_towels` | Date | Last washed: bathroom towels |
| `input_datetime.laundry_bed_sheets_guest` | Date | Last washed: guest sheets |
| `input_datetime.laundry_bed_sheets_master` | Date | Last washed: master sheets |
| `input_datetime.laundry_kitchen_towels` | Date | Last washed: kitchen towels |
| `input_select.house_mode` | Select | House mode (Home/Sleep/Party) |

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

### 6.1 Firmware & Version Management

> Pre-update: always take an HA backup and note current Z2M device count before any firmware change.

#### SLZB-06 Core Firmware

| Field | Value |
|-------|-------|
| Current | v3.1.6.dev |
| Update method | Web UI (http://10.0.0.51) > Settings > OTA update |
| Fallback | Download `.bin` from SMLIGHT GitHub releases, flash via Web UI upload |

#### SLZB-06 Radio Firmware (CC2652P)

| Field | Value |
|-------|-------|
| Current | 20240710 |
| Update method | Web UI > Settings > Zigbee flasher (OTA) |
| Alternative | TI SmartRF Flash Programmer 2 (USB direct, requires physical access) |
| Coordinator file | Koenkk Z2M coordinator firmware repository |

#### SLZB-06MU Firmware

| Field | Value |
|-------|-------|
| Current | MultiPAN/RCP (flashed 2026-01-11) |
| Update method | Web UI (http://10.0.0.52) > Settings > OTA update |
| HA entities | `update.slzb_06mu_core_firmware`, `update.slzb_06mu_zigbee_firmware` (report available versions) |

#### Zigbee2MQTT Version

| Field | Value |
|-------|-------|
| Current | v2.8.0-1 |
| Update method | HA Settings > Add-ons > Zigbee2MQTT > Update |
| Config persistence | Add-on stores config in internal `options.json` (see recovery runbook S8) |

#### Pre-Update Checklist

1. Take HA backup: `ssh hassio@ha "bash -l -c 'ha backups new --name pre-firmware-YYYYMMDD'"`
2. Note current Z2M device count (run `ha.z2m.devices.snapshot` or check Z2M dashboard)
3. Verify `ops/bindings/z2m.devices.yaml` is fresh (< 14 days)
4. If updating radio firmware: note current radio version from Web UI

#### Post-Update Validation

1. Run `./bin/ops cap run ha.z2m.devices.snapshot` — compare device count to pre-update
2. Check Z2M dashboard: all 6 devices reporting battery levels
3. Verify automations still fire (trigger a button, check log)
4. Run `./bin/ops cap run spine.verify` — confirm D98, D99, D101 PASS

### 6.2 Z-Wave Integration (TubesZB)

> TubesZB ZAC93 (Zooz 800 Series Long Range) is on hand but not installed. This section documents the installation procedure.

#### Prerequisites

- TubesZB powered via PoE (connect to UDR7 or PoE switch)
- ESPHome firmware detected: HA entity `sensor.tubeszb_2026_zw_esp_ip_address` shows IP
- Static IP 10.0.0.90 assigned in UDR7 DHCP reservations (already configured)
- Z-Wave JS UI add-on installed (v0.29.1, currently stopped)

#### Installation Steps

1. **Physical placement:** Position TubesZB centrally, away from Zigbee coordinator (minimize 2.4GHz interference). Z-Wave uses 908MHz (US), so distance from WiFi AP is less critical.
2. **PoE connection:** Connect to UDR7 PoE port or PoE injector. Verify power LED.
3. **Verify ESPHome status:** HA > Settings > Devices > search `tubeszb`. Entity `sensor.tubeszb_2026_zw_esp_ip_address` should show `10.0.0.90`.
4. **Start Z-Wave JS UI add-on:** HA > Settings > Add-ons > Z-Wave JS UI > Start.

#### Z-Wave JS UI Configuration

1. Serial port: `tcp://10.0.0.90:6638`
2. Security keys: Generate via add-on settings (S0, S2 Unauthenticated, S2 Authenticated, S2 Access Control)
3. Network configuration: Leave defaults (Home ID auto-generated on first start)
4. Enable statistics: Optional (helps Z-Wave ecosystem)

#### First Device Pairing

1. Open Z-Wave JS UI dashboard (HA sidebar or `http://100.67.120.1:8123/api/hassio_ingress/<addon_slug>`)
2. Click "Add Node" (inclusion mode)
3. Put target device in pairing mode (device-specific — usually press button 3x)
4. Wait for interview to complete (may take 1-5 minutes)
5. Verify entities appear in HA > Settings > Devices

#### Recovery

- **Network heal:** Z-Wave JS UI > Actions > Heal Network (run after moving nodes)
- **Network reset (last resort):** Z-Wave JS UI > Actions > Hard Reset. All devices must be re-included.
- **Controller replacement:** Export NVM backup from Z-Wave JS UI before replacing hardware. Import on new controller.
- **Backup/restore:** Z-Wave JS UI stores config in add-on data. HA backup includes this.

### 6.3 Matter/Thread Integration (SLZB-06MU)

> SLZB-06MU is installed (10.0.0.52) with MultiPAN/RCP firmware. Matter Server and OpenThread Border Router add-ons are present but not wired.

#### Current State

| Component | Version | Status |
|-----------|---------|--------|
| SLZB-06MU | MultiPAN/RCP (flashed 2026-01-11) | Ethernet connected, reachable |
| Matter Server add-on | v8.2.2 | Started |
| OpenThread Border Router add-on | v2.16.3 | Present, state UNKNOWN |
| HA Matter integration | Active | Not wired to SLZB-06MU |
| HA Thread integration | Active | Not wired to SLZB-06MU |

#### Wiring Procedure

1. **Configure OpenThread Border Router add-on:**
   - Set serial port to SLZB-06MU RCP device: TCP socket `tcp://10.0.0.52:6638` or `/dev/serial/by-id/...` if USB-attached
   - Set baudrate: 460800 (default for SLZB-06MU RCP mode)
   - Enable border router functionality
   - Start the add-on

2. **Verify Thread network formation:**
   - OpenThread Border Router dashboard shows "Leader" or "Router" state
   - Thread integration in HA shows the network with a dataset
   - Network credentials (commissioning dataset) visible in Thread integration

3. **Configure Matter Server:**
   - Matter Server should auto-detect the Thread network via mDNS
   - Verify in Matter Server logs: Thread border router discovered
   - No manual configuration needed if both add-ons are on the same host

#### Matter Device Commissioning

1. Open HA companion app (iOS/Android)
2. Settings > Devices & Services > Add Integration > Matter
3. Scan device QR code (on device box or in device app)
4. Choose Thread network (if device supports Thread) or WiFi
5. Multi-admin: device can be shared with Apple Home via "Add to other ecosystem"

#### Recovery

- **Thread network reset:** Delete Thread network in HA Thread integration. OpenThread Border Router will form a new network.
- **Matter fabric removal:** HA > Settings > Integrations > Matter > device > Remove. Device must be factory-reset for re-commissioning.
- **Re-commissioning:** Factory-reset device, re-scan QR code in HA companion app.
- **SLZB-06MU reflash:** If RCP firmware is corrupt, reflash via Web UI (http://10.0.0.52) > Settings > Firmware.

---

## 7. Backup & Restore Procedure

### App-Level Backup (HA Built-In)

**Method:** HA CLI via SSH add-on creates a full backup (config + add-ons + DB).

```
ssh hassio@ha "bash -l -c 'ha backups new --name ha-backup-YYYYMMDD'"
```

**Artifacts:** `/backup/*.tar` on HA VM, synced to NAS `/volume1/backups/homeassistant_backups/`.

**Retention:** Keep last 3 on HA, 7 days locally, 4 syncs on NAS.

### Offsite Sync (Retired)

~~Previously: HA (SSH add-on) -> MacBook (staging at `/tmp/ha-backup-staging`) -> Synology NAS (weekly launchd job).~~

**Current path:** vzdump captures VM 100 daily at 03:00, writing directly to NAS via NFS
(`proxmox-home:/mnt/pve/synology-backups` -> `nas:/volume1/backups/proxmox_backups`).
App-level `/backup/*.tar` files are included in the VM snapshot. The MacBook intermediary
(`com.ronny.ha-offsite-sync.plist`) is retired — vzdump provides better RPO (daily vs weekly)
with zero hops.

### VM-Level Backup

**Method:** Proxmox vzdump (P0 tier, daily 03:00) to NAS via NFS.
**See:** `HOME_BACKUP_STRATEGY.md` for schedule and retention.

### Restore Procedure

#### Option A: App-Level Restore (HA Backup)

Use when HA config is corrupt but the VM itself is healthy.

1. **Locate backup:** SSH to HA and list available backups:
   ```
   ssh hassio@ha "bash -l -c 'ha backups list'"
   ```
   Or check NAS: `nas:/volume1/backups/apps/home-assistant/`

2. **Upload backup if needed:** If restoring from NAS, scp the `.tar` to HA:
   ```
   scp nas:/volume1/backups/apps/home-assistant/ha-backup-YYYYMMDD.tar hassio@ha:/backup/
   ```

3. **Restore via CLI:**
   ```
   ssh hassio@ha "bash -l -c 'ha backups restore <SLUG> --homeassistant --addons'"
   ```
   Or restore via UI: HA Settings > System > Backups > select backup > Restore.

4. **Post-restore checklist:**
   - [ ] HA web UI accessible at `http://100.67.120.1:8123`
   - [ ] Zigbee2MQTT reconnects to SLZB-06 coordinator (check Z2M add-on logs)
   - [ ] All 14 automations are enabled (`ha automations list` or Settings > Automations)
   - [ ] Calendar integration (CalDAV) shows events
   - [ ] HACS integrations load without errors (Settings > Integrations > HACS)
   - [ ] SSH add-on is accessible (`ssh hassio@ha`)
   - [ ] Run `ops cap run ha.device.map.build` to verify entity count matches pre-restore
   - [ ] Run `ops cap run network.home.dhcp.audit` to verify DHCP state

#### Option B: VM-Level Restore (Proxmox vzdump)

Use when the entire VM 100 is lost or the disk is corrupt.

1. **Identify backup:** Check NAS vzdump store for most recent VM 100 backup:
   ```
   ssh root@proxmox-home "ls -la /mnt/nfs-backups/dump/ | grep vzdump-qemu-100"
   ```

2. **Restore VM:**
   ```
   ssh root@proxmox-home "qmrestore /mnt/nfs-backups/dump/vzdump-qemu-100-YYYY_MM_DD-HH_MM_SS.vma.zst 100 --force"
   ```

3. **Start VM and verify:**
   ```
   ssh root@proxmox-home "qm start 100"
   ```
   Wait 2-3 minutes for HA to boot, then run the post-restore checklist above.

4. **Network verification:** Confirm VM 100 has IP `100.67.120.1` (Tailscale) and `192.168.1.100` (LAN).

#### Recovery Time Objectives

| Scenario | RTO | Method |
|----------|-----|--------|
| Config corruption | ~10 min | App-level restore from local `/backup/` |
| Add-on failure | ~15 min | App-level restore (includes add-ons) |
| VM disk failure | ~30 min | vzdump restore + boot |
| Full host failure | ~1 hour | vzdump restore on alternate Proxmox node |

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
