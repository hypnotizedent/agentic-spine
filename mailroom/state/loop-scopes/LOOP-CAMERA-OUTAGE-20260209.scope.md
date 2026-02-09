# LOOP-CAMERA-OUTAGE-20260209

> **Status:** open
> **Blocked By:** none
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Severity:** high
> **Related:** LOOP-CAMERA-BASELINE-20260208

---

## Executive Summary

All 12 NVR camera channels show no live video in the Hikvision web UI at `http://192.168.1.216`. The NVR itself is healthy (HTTP 200, ISAPI responding, RTSP port 554 open) but no camera feeds are rendering. This was observed immediately after restoring the NVR to its SSOT IP (.216) via UDR6 DHCP reservation + power cycle.

Previous state (2026-02-08 ISAPI audit): 8 of 12 channels online, 4 offline. Current state: 0 of 12 showing video.

---

## Observed State (2026-02-09 ~17:52 EST)

- **NVR web UI:** accessible at `http://192.168.1.216`, logged in as `admin`
- **Channel list visible:** 12 channels with names (FRONT DRIVE, ALLY WAY, OFFICE, IPCamera 04, IPCamera 05, BAY 5 BACK, FRONT EXIT, STICKER, EMB, DTG, SCREEN ROOM, DARK ROOM)
- **Live view:** all 12 tiles are grey/black — no video feeds
- **NVR ports:** 80 (HTTP), 554 (RTSP), 8000 (SDK) all open
- **ISAPI:** returns 401 (auth required) — NVR creds not yet in Infisical

---

## Possible Causes (to triage)

| # | Hypothesis | Likelihood | Check |
|---|-----------|------------|-------|
| 1 | NVR just power-cycled — cameras on internal PoE network still reconnecting | High | Wait 5-10 min, refresh web UI |
| 2 | Netgear PoE switch (uplink to NVR PoE ports) lost power or not recovered | Medium | Physical check upstairs 9U rack |
| 3 | Browser plugin not installed — Hikvision requires WebSocket/NPAPI for live view | Medium | "Download Plug-In" button visible in UI; try RTSP via VLC instead |
| 4 | Camera internal PoE network (192.168.254.0/24) disrupted | Medium | ISAPI channel status query once creds are stored |
| 5 | NVR IP change broke camera-to-NVR reverse path (cameras reference NVR gateway) | Low | NVR internal PoE network is isolated; IP change was on shop LAN side only |

---

## Blockers

### NVR credentials not in Infisical

NVR creds (`NVR_ADMIN_USER`, `NVR_ADMIN_PASSWORD`) are referenced across CAMERA_SSOT.md and multiple capabilities as `infrastructure/prod:/spine/shop/nvr/*` but the Infisical folder `/spine/shop/nvr/` does not exist yet. This blocks automated ISAPI queries.

**Action:** Create folder + store creds (same pattern as AP wifi creds).

---

## Triage Steps

1. [ ] **Wait + refresh** — NVR was just power cycled; cameras may need 5-10 min to reconnect via internal PoE
2. [ ] **Store NVR creds in Infisical** — create `/spine/shop/nvr/` folder, store `NVR_ADMIN_USER` + `NVR_ADMIN_PASSWORD`
3. [ ] **ISAPI channel status** — `curl --digest -u user:pass http://192.168.1.216/ISAPI/ContentMgmt/InputProxy/channels/status` from pve
4. [ ] **RTSP test** — try `ffprobe rtsp://user:pass@192.168.1.216:554/Streaming/Channels/101` from pve to check if streams exist independent of web UI
5. [ ] **Physical check** — verify Netgear PoE switch upstairs is powered on and uplinked to NVR
6. [ ] **Browser plugin** — install Hikvision Web Components if live view is a browser rendering issue

---

## SSOT Impact

- CAMERA_SSOT.md channel registry (last verified 2026-02-08) may need update after triage
- NVR IP drift (.104 → .216) resolved this session — SSOT was correct, NVR was on DHCP
- UDR6 DHCP reservation created for MAC `24:0F:9B:30:F1:E7` → `.216` (persistent)

---

## Audit Trail

| Date | Event |
|------|-------|
| 2026-02-08 | ISAPI audit: 8/12 online, 4 offline (LOOP-CAMERA-BASELINE) |
| 2026-02-09 | NVR found at DHCP .104, SSOT said .216 — DHCP reservation created |
| 2026-02-09 | NVR power cycled, confirmed at .216 (HTTP 200, ARP confirmed) |
| 2026-02-09 | Web UI shows 12 channels, 0 video feeds — this loop opened |
