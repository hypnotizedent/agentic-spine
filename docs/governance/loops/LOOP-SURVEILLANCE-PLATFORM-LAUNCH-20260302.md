---
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
status: planned
owner: "@ronny"
created: "2026-03-02"
target_close: "2026-04-30"
title: "Mint Visibility Platform — Full Surveillance Stack Launch (Shop)"
horizon: later
execution_readiness: blocked
activation_trigger: dependency
depends_on_loop: LOOP-CAMERA-OUTAGE-20260209
---

# LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302

## Purpose

Stand up a production-grade, spine-governed surveillance platform at the Mint Prints shop. Replaces raw Hikvision NVR-only access with an AI-powered, role-scoped, agentic-integrated visibility system. Establishes the multi-location pattern for future sites.

Comprises two parallel sub-initiatives:
1. **Surveillance Stack** — Frigate NVR + go2rtc + Tesla P40 AI detection + Pi kiosk displays + ESP32 press arm cameras
2. **Shop HA** — Dedicated Home Assistant instance at the shop as the local automation brain and Frigate event consumer

---

## Blockers (must clear before T2+)

- **B1 — Feb-9 camera outage unresolved.** All 12 channels dark after NVR power cycle. NVR ISAPI creds not in Infisical. No baseline stream available until this is fixed. Blocks all Frigate configuration work.
- **B2 — Channel location labels all `pending-survey`.** Cannot define Frigate detection zones until every channel has a verified physical label.
- **B3 — Tesla P40 not yet installed.** Procurement/physical install must happen before GPU passthrough can be configured in PVE.

---

## Tier 0 — Blockers (do these first, in order)

### T0-A: Resolve Feb-9 Camera Outage
- Store NVR credentials (`nvr-shop` — `192.168.1.216`) in Infisical under `shop/nvr/`
- Run ISAPI query to enumerate all channel stream URLs
- Confirm all 12 channels show live video in Hikvision web UI
- Update CAMERA_SSOT.md: mark outage resolved, populate ISAPI-confirmed stream URLs
- **Gate:** 12/12 channels live and SSOT updated before proceeding

### T0-B: Camera Location Survey
- Walk the shop floor with NVR feed open
- Label all 12 channels with canonical location names (e.g., `front-exterior`, `back-door`, `press-floor-overview`, `parking-lot-east`, etc.)
- Update CAMERA_SSOT.md with verified location for every channel
- **Gate:** 0 channels with `pending-survey` before Frigate zone config begins

---

## Tier 1 — Hardware (parallel with T0 resolution)

### T1-A: Tesla P40 GPU Installation
**What:** Install Tesla P40 24GB into open PCIe x16 slot on R730XD.

**P40 Caveats (must acknowledge before install):**
- P40 is a **compute-only** data center card — no display outputs, no NVDEC hardware video decode
- Frigate will use the P40 for **TensorRT object detection inference only** (~12ms/frame)
- Video stream **decode** (H.264/H.265) will remain **CPU-bound** — this is acceptable on the R730XD (192GB RAM, high core count) but must be monitored
- The P40 requires **active cooling** — verify rack airflow or add a fan bracket before install
- PVE PCIe passthrough to the surveillance-stack VM requires IOMMU enabled in BIOS + PVE config
- No NVENC = no GPU-accelerated recording transcode (recordings stay in camera-native codec, which is fine for Frigate's use case)

**Tasks:**
- Physical install into R730XD PCIe slot
- Enable IOMMU in BIOS (if not already enabled for other VMs)
- Verify `lspci` sees the P40 from PVE host
- Configure PVE PCIe passthrough to VM 211
- Update SHOP_SERVER_SSOT.md with slot assignment and P40 spec

**Gate:** `nvidia-smi` shows P40 from inside surveillance-stack VM before Frigate GPU config

### T1-B: ESP32-CAM Press Arm Units — Procurement & Design
**What:** Small, cheap, WiFi camera units at each of the 12 press arm positions on the screen printing press. Not AI-detection cameras — pure RTSP stream for operator visibility.

**Spec:**
- Hardware: ESP32-CAM (AI-Thinker module) ~$8-12/unit x 12 = ~$100-150 total
- Firmware: ESPHome camera component or stock AI-Thinker firmware with MJPEG/RTSP stream
- Power: 5V USB-A or micro-USB from press arm power if available, else small USB power bank per arm
- Lens: stock wide-angle OV2640, sufficient for color station visibility at arm distance
- Network: dedicated `press-cams` SSID on shop WiFi, isolated VLAN recommended
- Naming convention: `press-cam-01` through `press-cam-12`, color position labeled in ESPHome config

**Tasks:**
- Procure 12x ESP32-CAM + 12x OV2640 wide lens + power adapters
- Flash ESPHome firmware with consistent stream config
- Mount to each press arm (adhesive mount + cable tie, replaceable design)
- Register all 12 in CAMERA_SSOT.md under `press-arm` section
- Add all 12 as go2rtc sources with friendly names

**Gate:** All 12 streams accessible from LAN before press operator TV is configured

### T1-C: Raspberry Pi Kiosk Display Units — Procurement
**What:** Pi 4 (2GB) per display location running Chromium in kiosk mode, pointed at a go2rtc multi-view URL. No login required from the TV — access is network-scoped.

**Display locations (initial):**

| Display | Location | View | Pi Hostname |
|---------|----------|------|-------------|
| Press TV | Next to press machine | 12-up press arm grid | `kiosk-press` |
| Production TV | Shop floor common area | Exterior cameras only | `kiosk-production` |
| Office/Ronny | Upstairs office or mobile | All cameras + events | Tailscale/remote |

**Tasks:**
- Procure 2x Raspberry Pi 4 (2GB) + cases + HDMI cables + power supplies
- Flash Raspberry Pi OS Lite, configure Chromium kiosk mode with target URL baked in
- Connect via shop LAN (wired ethernet preferred for reliability)
- Mount behind TVs cleanly (VESA mount adapter or adhesive)
- Register in DEVICE_IDENTITY_SSOT.md

---

## Tier 2 — VM Provisioning

### T2-A: Provision surveillance-stack (VM 211)
- Clone from Ubuntu 22.04 base template on PVE
- Hostname: `surveillance-stack`
- IP: `192.168.1.211` (static, reserved in UDR6 DHCP)
- Storage: allocate 500GB–1TB thin-provisioned on PVE local storage for Frigate recordings (separate from NFS media pool)
- RAM: 16GB allocated (Frigate is memory-hungry with multiple cameras)
- CPU: 8 vCPUs
- PCIe passthrough: Tesla P40 (from T1-A)
- Network: access to `192.168.1.0/24` (shop LAN) and `192.168.254.0/24` (camera VLAN) via bridge config
- Add to vzdump backup job after stabilization
- Register in SHOP_VM_ARCHITECTURE.md and DEVICE_IDENTITY_SSOT.md

### T2-B: Provision shop-ha (VM 212)
- Install Home Assistant OS (HAOS) via QEMU on PVE (standard install method)
- Hostname: `shop-ha`
- IP: `192.168.1.212` (static)
- RAM: 4GB, CPU: 4 vCPU (HA is lightweight)
- Storage: 64GB thin-provisioned (OS + history + backups)
- Add to Tailscale for remote access + Infisical secret storage for HA long-lived token
- Register in SHOP_VM_ARCHITECTURE.md and DEVICE_IDENTITY_SSOT.md

---

## Tier 3 — Frigate Deployment

### T3-A: Frigate Docker Compose on surveillance-stack
**Stack:** `blakeblackshear/frigate:stable` (Docker Compose)

**Config highlights:**
```yaml
detectors:
  tensorrt:
    type: tensorrt
    device: 0

mqtt:
  enabled: true
  host: 192.168.1.212
  port: 1883

cameras:
  front-exterior:
    ffmpeg:
      inputs:
        - path: rtsp://user:pass@192.168.254.1:554/Streaming/channels/101
          roles: [detect]
        - path: rtsp://user:pass@192.168.254.1:554/Streaming/channels/1
          roles: [record]
  press-cam-01:
    detect:
      enabled: false
    record:
      enabled: false

record:
  enabled: true
  retain:
    days: 14
    mode: motion
  events:
    retain:
      default: 30

objects:
  track: [person, car, truck, package]

semantic_search:
  enabled: true
  reindex: false
```

**Tasks:**
- Write Frigate config from T0-B survey data (zones per labeled camera)
- Configure TensorRT model download (Frigate downloads on first run)
- Validate detection FPS on P40 with all 12 cameras active
- Tune motion masks per camera to eliminate false positives (press floor is high motion)
- Configure object retention: exterior 30-day event retention, press-arm stream-only no retention

### T3-B: go2rtc Multi-View Streams
go2rtc is bundled in Frigate. Expose named stream groups:

| Stream Name | Cameras Included | Consumer |
|------------|-----------------|----------|
| `view-press-operator` | press-cam-01 through press-cam-12 (12-up grid) | kiosk-press TV |
| `view-production-floor` | all exterior Hikvision channels | kiosk-production TV |
| `view-ronny-full` | all 24 cameras (12 Hikvision + 12 press) | Ronny — Tailscale/remote |

- Kiosk Pi browsers hit `http://192.168.1.211:1984/` (go2rtc UI) or custom HTML multi-view page
- Remote Ronny access via Cloudflare tunnel or Tailscale to go2rtc port

---

## Tier 4 — Shop Home Assistant (VM 212)

### Why a Separate Shop HA

The home HA (currently the only instance) runs at `10.0.0.x` — the home network. It manages home devices, Zigbee coordinators, and home automations. Mixing shop surveillance events into the home HA creates:
- Network dependency: shop events require tunnel back to home HA
- Governance boundary violation: shop ops (deliveries, press alerts, access events) are Mint Prints operational data, not personal home data
- Reliability risk: a home HA restart silences shop alerts
- Multi-tenant confusion: a future second location would compound this

The boundary decision: **one HA instance per physical location, with Nabu Casa or HA Cloud federation for cross-site visibility if desired later.**

### T4-A: Shop HA Core Integrations

| Integration | Purpose | Config source |
|-------------|---------|---------------|
| Frigate (custom component via HACS) | Camera events, snapshots, person/vehicle alerts | Frigate MQTT on 192.168.1.211 |
| Mosquitto broker (add-on) | MQTT broker for Frigate + future shop devices | Local to shop-ha |
| go2rtc (add-on or integration) | Camera stream thumbnails in HA dashboard | Points to surveillance-stack |
| Mobile App | Push notifications to Ronny's phone | Nabu Casa or direct |
| UniFi (optional) | Client presence detection (who's on shop WiFi) | UDR6 API |

**Intentionally NOT adding to shop HA initially:**
- Zigbee (no coordinator purchased for shop yet — future expansion)
- Matter/Thread (same)
- Home devices (stays home-only)

### T4-B: Shop HA Automations (initial set)

```
AUTOMATION: Person at front door
  Trigger: Frigate event — camera: front-exterior, label: person, score > 0.75
  Action: Push notification to Ronny with snapshot + "Someone at the front door"
  Time filter: any time

AUTOMATION: Vehicle arriving
  Trigger: Frigate event — camera: parking-lot-*, label: car/truck, entering zone: arrival
  Action: Push notification — "Vehicle arriving at shop"

AUTOMATION: Delivery detected
  Trigger: Frigate event — person detected at back-door, no motion for 60s after
  Action: Push notification — "Possible delivery at back door"

AUTOMATION: After-hours motion
  Trigger: Any exterior camera — motion detected, time: 10pm-6am
  Action: Push notification with snapshot — "After-hours motion: [camera name]"

AUTOMATION: Press idle alert (future)
  Trigger: press-floor-overview — no motion for X minutes during scheduled production hours
  Action: Spine mailroom event (production slowdown signal)
```

---

## Tier 5 — Spine Integration

### T5-A: Register New Capabilities
Two new capabilities to add to the ops binding registry:

**`surveillance.stack.status`**
- Mirrors `media.status` pattern
- Checks: surveillance-stack VM up, Frigate container health, detection FPS, camera online count, disk usage for recordings
- Bridge-accessible (read-only, auto-approve)

**`surveillance.event.query`**
- Read-only query to Frigate's event database via its API
- Params: camera, label, time range
- Returns: event count, last event timestamp, snapshot URL
- Bridge-accessible (read-only, auto-approve)

**`shop.ha.status`**
- Checks shop-ha VM up, HA core version, Frigate integration connected, MQTT broker healthy
- Bridge-accessible (read-only, auto-approve)

### T5-B: SSOT Updates Required

| File | Change |
|------|--------|
| `CAMERA_SSOT.md` | Rename to shop-scoped, add ch13-14 (doorbell), add press-arm section (12 ESP32 units), mark outage resolved (post T0) |
| `SHOP_VM_ARCHITECTURE.md` | Add VM 211 (surveillance-stack) and VM 212 (shop-ha) with roles |
| `SHOP_SERVER_SSOT.md` | Add P40 GPU spec and PCIe slot assignment |
| `DEVICE_IDENTITY_SSOT.md` | Add surveillance-stack (.211), shop-ha (.212), kiosk-press, kiosk-production IPs |

### T5-C: Multi-Location Template
When a second location is set up (home, second shop, warehouse, etc.):

```
CAMERA_SSOT__{location}.md
SURVEILLANCE_ROLES__{location}.md
surveillance-stack @ {location}
{location}-ha
```

The `SURVEILLANCE_ROLES.md` at global level defines cross-location access:
- Ronny: sees all locations
- Staff: sees their assigned location only
- No cross-location streams accessible without explicit grant

---

## Tier 6 — Hardening & Governance

### T6-A: Access Security
- All go2rtc stream URLs are LAN-only by default; Cloudflare tunnel exposes only Ronny's authenticated view
- Press-arm ESP32 cameras on isolated VLAN (`press-cams`) — no internet access, no cross-VLAN routing except to surveillance-stack
- Camera VLAN (192.168.254.0/24) remains isolated — Hikvision cameras blocked from internet (already enforced by UDR6 firewall)
- shop-ha remote access via Tailscale only (no public exposure of HA directly)

### T6-B: SURVEILLANCE_ROLES.md
See separate file for full access boundary definitions.

### T6-C: Backup & Retention Policy
- Frigate recordings: 14-day rolling motion-based retention, 30-day event retention
- Exterior critical events (person detection, vehicle): 90-day retention
- Press-arm streams: no recording (operator visibility only)
- shop-ha: daily backup via HA backup add-on to TrueNAS share

---

## Success Criteria (loop closure gates)

- [ ] All 12 Hikvision channels live in Frigate with verified zone labels
- [ ] Doorbell camera on ch13 live
- [ ] All 12 ESP32 press arm cameras streaming to go2rtc
- [ ] Press operator TV showing 12-up press view via Pi kiosk
- [ ] Production TV showing exterior view via Pi kiosk
- [ ] Ronny receives push notification when person detected at front exterior
- [ ] After-hours motion alert firing correctly (tested)
- [ ] surveillance.stack.status capability registered and callable from bridge
- [ ] shop-ha fully deployed, Frigate integration confirmed healthy
- [ ] All SSOT amendments applied and verified
- [ ] SURVEILLANCE_ROLES.md committed to governance docs

---

## Related Documents

- [CAMERA_SSOT.md](../CAMERA_SSOT.md)
- [SHOP_VM_ARCHITECTURE.md](../SHOP_VM_ARCHITECTURE.md)
- [SHOP_SERVER_SSOT.md](../SHOP_SERVER_SSOT.md)
- [SURVEILLANCE_PLATFORM_SSOT.md](../../core/SURVEILLANCE_PLATFORM_SSOT.md)
- [SURVEILLANCE_ROLES.md](../SURVEILLANCE_ROLES.md)
- [LOOP-CAMERA-OUTAGE-20260209](../../mailroom/state/loop-scopes/LOOP-CAMERA-OUTAGE-20260209.scope.md)
