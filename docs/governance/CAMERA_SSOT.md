---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
verification_method: live-isapi-query + receipt
scope: camera-infrastructure
parent_receipts:
  - "DELL_N2024P_FACTORY_RESET_20260205_122838"
---

# CAMERA SSOT

> Canonical, spine-native description of the **Shop camera system**.
>
> **Covers:** Hikvision NVR (ERI-K216-P16), all camera channels, camera network topology (192.168.254.0/24), storage, and Frigate readiness.
>
> **Authority boundary:**
> - Camera channels, NVR config, camera network: this doc (canonical)
> - Rack inventory, switch port assignment, shop LAN topology: [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md)
> - Device naming/identity: [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md)
>
> **No secrets rule:** Credentials, RTSP URLs, and passwords must be stored in Infisical. This repo never contains secret values.

---

## Quick Reference

| Item | Value |
|------|-------|
| NVR IP (Shop LAN) | `192.168.12.216` (`nvr-shop`) |
| NVR Model | Hikvision ERI-K216-P16 |
| Total Channels | 16 (12 configured, 8 online, 4 offline) |
| Camera VLAN | `192.168.254.0/24` (NVR internal PoE network) |
| Credentials (Infisical) | `infrastructure/prod:/spine/shop/nvr/*` |
| Loop | LOOP-CAMERA-BASELINE-20260208 |

---

## NVR Hardware

| Property | Value | Verified |
|----------|-------|----------|
| **Model** | Hikvision ERI-K216-P16 | 2026-02-08 |
| **Serial** | ERI-K216-P161620220307CCRRJ54340404WCVU | 2026-02-08 |
| **Firmware** | V4.30.216 build 231108 | 2026-02-08 |
| **MAC** | 24:0F:9B:30:F1:E7 | 2026-02-08 |
| **Channels** | 16 PoE (internal switch) | 2026-02-08 |
| **Location** | Upstairs 9U rack (separate from main rack) | 2026-02-05 |
| **Shop LAN IP** | 192.168.12.216 | 2026-02-08 |
| **Switch Port** | Gi1/0/4 (Dell N2024P) | 2026-02-05 |
| **ISAPI Base** | `http://192.168.12.216/ISAPI/` | 2026-02-08 |
| **SDK Port** | 8000 | 2026-02-08 |
| **RTSP Port** | 554 | 2026-02-08 |
| **HTTP Port** | 80 | 2026-02-08 |

---

## Network Topology

```
Shop LAN (192.168.12.0/24)
    |
    +-- Dell N2024P Switch (Gi1/0/4) ---> NVR (192.168.12.216)
                                             |
                                             +-- NVR Internal PoE Network (192.168.254.0/24)
                                             |       |
                                             |       +-- Netgear PoE Switch (uplink to NVR PoE ports)
                                             |               |
                                             |               +-- Camera ch1  (192.168.254.9)
                                             |               +-- Camera ch2  (192.168.254.3)  [OFFLINE]
                                             |               +-- Camera ch3  (192.168.254.4)  [OFFLINE]
                                             |               +-- Camera ch4  (192.168.254.7)  [OFFLINE]
                                             |               +-- Camera ch5  (192.168.254.5)  [OFFLINE]
                                             |               +-- Camera ch6  (192.168.254.16)
                                             |               +-- Camera ch7  (192.168.254.12)
                                             |               +-- Camera ch8  (192.168.254.10)
                                             |               +-- Camera ch9  (192.168.254.6)
                                             |               +-- Camera ch10 (192.168.254.17)
                                             |               +-- Camera ch11 (192.168.254.13)
                                             |               +-- Camera ch12 (192.168.254.8)
                                             |
                                             +-- 1x 4TB HDD (recording storage)
```

- Cameras are on the NVR's internal PoE network (`192.168.254.0/24`), isolated from the shop LAN
- A Netgear PoE switch provides power and connectivity, uplinked to the NVR's PoE ports
- NVR management interface is accessible from the shop LAN at `192.168.12.216`
- RTSP streams are accessible from the shop LAN via the NVR (not directly from cameras)

---

## Channel Registry

Live ISAPI query, 2026-02-08:

| Channel | Internal IP | Online | Detect Result | Physical Location | Model |
|---------|-------------|--------|---------------|-------------------|-------|
| 1 | 192.168.254.9 | Yes | connect | TBD | TBD |
| 2 | 192.168.254.3 | **No** | notExist | TBD | TBD |
| 3 | 192.168.254.4 | **No** | notExist | TBD | TBD |
| 4 | 192.168.254.7 | **No** | notExist | TBD | TBD |
| 5 | 192.168.254.5 | **No** | netUnreachable | TBD | TBD |
| 6 | 192.168.254.16 | Yes | connect | TBD | TBD |
| 7 | 192.168.254.12 | Yes | connect | TBD | TBD |
| 8 | 192.168.254.10 | Yes | connect | TBD | TBD |
| 9 | 192.168.254.6 | Yes | connect | TBD | TBD |
| 10 | 192.168.254.17 | Yes | connect | TBD | TBD |
| 11 | 192.168.254.13 | Yes | connect | TBD | TBD |
| 12 | 192.168.254.8 | Yes | connect | TBD | TBD |

**Notes:**
- Channels 13-16 are not configured (no cameras assigned)
- Channel 5 reassigned from `192.168.254.7` to `.5` (2026-02-08, GAP-OP-032 fixed). Now `netUnreachable` — camera physically disconnected or needs IP update on hardware
- Channels 2-4 report `notExist` — powered off or disconnected from PoE switch (GAP-OP-031)
- Physical locations and camera models require on-site audit (LOOP-CAMERA-BASELINE-20260208, P3-P4)

---

## Frigate Readiness

Everything an agent needs to generate a Frigate configuration for this NVR:

| Property | Value |
|----------|-------|
| **RTSP URL Pattern (main)** | RTSP scheme + `{user}:{pass}@192.168.12.216:554/Streaming/Channels/{ch}01` |
| **RTSP URL Pattern (sub)** | RTSP scheme + `{user}:{pass}@192.168.12.216:554/Streaming/Channels/{ch}02` |
| **Stream Types** | Main stream (01) + Sub stream (02) per channel |
| **Video Codec** | H.265+ (main), H.264 (sub) — typical Hikvision defaults |
| **Protocols** | Hikvision native (ISAPI/SDK) + ONVIF |
| **RTSP Port** | 554 |
| **SDK Port** | 8000 |
| **ONVIF Port** | Typically 80 (verify per-camera) |
| **Authentication** | Digest (RTSP), Digest (ISAPI) |
| **Online Channels** | 1, 6, 7, 8, 9, 10, 11, 12 (8 total) |
| **Credentials** | Infisical: `infrastructure/prod:/spine/shop/nvr/*` |

**Channel numbering in RTSP URLs:**
- `{ch}` is the channel number (1-12)
- Main stream suffix: `01` (e.g., channel 1 main = `/Streaming/Channels/101`)
- Sub stream suffix: `02` (e.g., channel 1 sub = `/Streaming/Channels/102`)

**Frigate detect config recommendation:**
- Use sub stream (lower resolution) for object detection
- Use main stream for recording
- Set `detect.fps` to 5 for reasonable CPU usage
- H.265+ may require hardware decoding (Intel QSV or VAAPI)

---

## Storage

| Property | Value | Verified |
|----------|-------|----------|
| **Drive Count** | 1 | 2026-02-08 |
| **Drive Capacity** | 4TB SATA HDD | 2026-02-08 |
| **Drive Status** | ok | 2026-02-08 |
| **Space Status** | full | 2026-02-08 |
| **Overwrite Mode** | overwrite/quota (oldest recordings deleted when full) | 2026-02-08 |

---

## Known Issues

| GAP ID | Summary | Severity | Status | Fix |
|--------|---------|----------|--------|-----|
| GAP-OP-031 | Cameras ch2-4 offline (`notExist`) | medium | open | Physical visit: check Netgear PoE switch, camera power, cabling |
| GAP-OP-032 | ~~Ch5 IP conflict~~ | low | **fixed** | Reassigned ch5 from `.7` to `.5` via ISAPI PUT (2026-02-08) |

Additional incomplete items:
- **Physical location labels**: All 12 channels have `TBD` location — requires on-site walk with camera feed open
- **Camera models/firmware**: All channels have `TBD` model — queryable via ISAPI once cameras are online (P3)

---

## Verification Commands

All commands use digest authentication. **No credentials in this document** — retrieve from Infisical at `infrastructure/prod:/spine/shop/nvr/*`.

```bash
# System info (NVR model, serial, firmware)
curl -s --digest -u "{user}:{pass}" \
  "http://192.168.12.216/ISAPI/System/deviceInfo" | xmllint --format -

# Channel status (all channels)
curl -s --digest -u "{user}:{pass}" \
  "http://192.168.12.216/ISAPI/ContentMgmt/InputProxy/channels" | xmllint --format -

# Single channel status
curl -s --digest -u "{user}:{pass}" \
  "http://192.168.12.216/ISAPI/ContentMgmt/InputProxy/channels/{ch}/status" | xmllint --format -

# HDD status
curl -s --digest -u "{user}:{pass}" \
  "http://192.168.12.216/ISAPI/ContentMgmt/Storage" | xmllint --format -

# Camera detect (online/offline/conflict)
curl -s --digest -u "{user}:{pass}" \
  "http://192.168.12.216/ISAPI/ContentMgmt/InputProxy/channels/{ch}/detect" | xmllint --format -

# Streaming capabilities (codec info per channel)
curl -s --digest -u "{user}:{pass}" \
  "http://192.168.12.216/ISAPI/Streaming/channels/{ch}01/capabilities" | xmllint --format -
```

---

## Evidence

| Date | Source | Summary |
|------|--------|---------|
| 2026-02-08 | Live ISAPI query (SSH from pve) | 12 channels enumerated, 8 online, 3 offline, 1 IP conflict. NVR firmware V4.30.216. 1x 4TB HDD status ok/full. |
| 2026-02-05 | Dell N2024P factory reset receipt | NVR confirmed on Gi1/0/4, MAC 24:0F:9B:30:F1:E7, IP 192.168.12.216 |

---

## Related Documents

- [SHOP_SERVER_SSOT.md](SHOP_SERVER_SSOT.md) — rack inventory, switch port assignments, shop LAN
- [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) — device naming and identity
- [SECRETS_POLICY.md](SECRETS_POLICY.md) — credential storage rules

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
