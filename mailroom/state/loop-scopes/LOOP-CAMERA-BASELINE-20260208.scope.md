# LOOP-CAMERA-BASELINE-20260208

> **Status:** open
> **Blocked By:** none
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

The shop NVR (Hikvision ERI-K216-P16) was audited live via ISAPI on 2026-02-08, revealing 8 online cameras, 3 offline (ch2-4), and 1 IP conflict (ch5). Camera data has been extracted from SHOP_SERVER_SSOT.md into a dedicated CAMERA_SSOT.md for agent-consumable camera configuration.

This loop tracks the remaining work: fixing the IP conflict, restoring offline cameras, completing the camera inventory (models, firmware, physical locations), and preparing for Frigate deployment.

---

## Current State

- **CAMERA_SSOT.md** created with all live-verified data
- 8 of 12 configured channels are online and streaming
- 3 channels offline (`notExist`) — likely powered off or disconnected at the Netgear PoE switch
- 1 channel has IP conflict (`ipAddrConflict`) — ch5 shares IP with ch4
- Physical locations and camera models are unknown for all channels
- NVR storage is full (1x 4TB, overwrite mode)

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Create CAMERA_SSOT.md with verified data | None | **done** |
| P1 | Fix ch5 IP conflict via NVR ISAPI | None (remote) | **done** |
| P2 | Restore ch2-4 cameras | Physical visit | pending |
| P3 | Query camera models/firmware per channel via ISAPI | P2 (all online) | pending |
| P4 | Physical location audit | On-site walk | pending |
| P5 | Frigate deployment planning | P2 + P3 + P4 | pending |

---

## Phase Details

### P0 — Create CAMERA_SSOT.md (DONE)

- Extracted camera data from SHOP_SERVER_SSOT.md into dedicated CAMERA_SSOT.md
- Documented all 12 channels with live ISAPI data
- Added Frigate readiness section with RTSP patterns and codec info
- Registered GAP-OP-031 (offline cameras) and GAP-OP-032 (IP conflict)
- Added camera-ssot entry to SSOT_REGISTRY.yaml

### P1 — Fix ch5 IP conflict (remote)

Channel 5 and channel 4 both have IP `192.168.254.7`. This is a configuration error in the NVR, fixable remotely.

Steps:
1. Query current ch5 config: `GET /ISAPI/ContentMgmt/InputProxy/channels/5`
2. Choose a free IP on `192.168.254.0/24` (avoid .3, .4, .6, .7, .8, .9, .10, .12, .13, .16, .17)
3. Update ch5 IP: `PUT /ISAPI/ContentMgmt/InputProxy/channels/5` with new IP
4. Verify: `GET /ISAPI/ContentMgmt/InputProxy/channels/5/detect` — should show `connect` (not `ipAddrConflict`)
5. Update CAMERA_SSOT.md channel registry

**Closes:** GAP-OP-032

### P2 — Restore ch2-4 cameras (physical)

Channels 2, 3, 4 report `notExist` — cameras are powered off or disconnected from the Netgear PoE switch.

Steps:
1. Physical visit to upstairs 9U rack
2. Check Netgear PoE switch — are ports for ch2-4 powered? LEDs?
3. Trace cables from PoE switch to cameras
4. Check camera power (PoE indicator lights)
5. If cameras are physically present but unpowered, check PoE budget on Netgear switch
6. Once cameras are online, verify via ISAPI detect endpoint
7. Update CAMERA_SSOT.md channel registry

**Closes:** GAP-OP-031

### P3 — Query camera models/firmware (remote, after P2)

Once all cameras are online, query each channel for hardware details:

```bash
# Per-channel device info
curl -s --digest -u "{user}:{pass}" \
  "http://192.168.12.216/ISAPI/ContentMgmt/InputProxy/channels/{ch}/deviceInfo"
```

Populate CAMERA_SSOT.md channel registry with:
- Camera model
- Firmware version
- Resolution capabilities

### P4 — Physical location audit (on-site)

Walk the shop with NVR live view open on phone/laptop:
- For each online channel, identify the physical mounting location
- Label each channel in CAMERA_SSOT.md (e.g., "Front door", "Shop floor east", "Parking lot")
- Take photos for documentation if useful

### P5 — Frigate deployment planning

Depends on P2-P4 completion. Scope:
- Choose Frigate host VM (likely ai-consolidation VM 207 or dedicated)
- Generate Frigate config from CAMERA_SSOT.md data
- Configure detection zones based on physical locations
- Set up coral/GPU acceleration if available
- Wire into Home Assistant if desired

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| CAMERA_SSOT.md has all 12 channels documented | Visual inspection |
| Ch5 IP conflict resolved | ISAPI detect shows `connect` |
| Ch2-4 cameras restored | ISAPI detect shows `connect` for all |
| All channels have model/firmware | No `TBD` in Model column |
| All channels have physical location | No `TBD` in Location column |
| GAP-OP-031 closed | operational.gaps.yaml status=fixed |
| GAP-OP-032 closed | operational.gaps.yaml status=fixed |

---

## Non-Goals

- Do NOT change NVR firmware (upgrade is a separate decision)
- Do NOT add new cameras to the NVR (only restore existing)
- Do NOT deploy Frigate in this loop (P5 is planning only)
- Do NOT change NVR storage configuration (overwrite mode is acceptable)

---

## Evidence

- Live ISAPI query from pve (2026-02-08) — channel status, detect results, HDD status
- Dell N2024P factory reset receipt (2026-02-05) — NVR on Gi1/0/4
- `docs/governance/CAMERA_SSOT.md` — canonical camera doc

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
