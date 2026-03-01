---
loop_id: LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228
created: 2026-02-28
status: closed
owner: "@ronny"
scope: ha
priority: medium
objective: Achieve canonical reliability for everyday HA devices (Zigbee buttons, Matter buttons, TP-Link plugs, Tuya bulbs). Fix ghost devices, dead buttons, orphan plugs, unavailable bulbs, missing monitoring. Unified device health gate across all protocols.
---

# Loop Scope: LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228

## Objective

Achieve canonical reliability for everyday HA devices (Zigbee buttons, Matter buttons, TP-Link plugs, Tuya bulbs). Fix ghost devices, dead buttons, orphan plugs, unavailable bulbs, missing monitoring. Unified device health gate across all protocols.

## Step 1: Forensic Audit + Gap Registration (COMPLETE)

Full read-only audit of Zigbee, Matter, TP-Link, and Tuya device health.
Live HA API state snapshot taken at 2026-02-28T01:30Z.

### Zigbee Reliability (8 gaps)
- GAP-OP-1070: Scene switch ghost device — TS0044 missing from database.db (CRITICAL)
- GAP-OP-1071: Z2M availability config empty — no device tracking (HIGH)
- GAP-OP-1072: Z2M channel 11 — max Wi-Fi interference (MEDIUM)
- GAP-OP-1073: Z2M default network key — insecure (MEDIUM)
- GAP-OP-1074: Zero Zigbee routers — star topology, no mesh (MEDIUM)
- GAP-OP-1075: Hold automation bug — '_hold' != 'hold' (LOW)
- GAP-OP-1076: z2m.devices.yaml snapshot stale (MEDIUM)
- GAP-OP-1077: Health cap missing database integrity check (HIGH)

### Matter Reliability (2 gaps)
- GAP-OP-1078: BILRESA Matter button dead 10+ days (CRITICAL)
- GAP-OP-1079: Matter devices marked orphan in device map (LOW)

### TP-Link Reliability (4 gaps)
- GAP-OP-1080: B6EE plug offline — only tracker entity remains (MEDIUM)
- GAP-OP-1081: King Lamp entity naming confusion (LOW)
- GAP-OP-1082: BB2E plug orphaned — no name, no registry (LOW)
- GAP-OP-1083: 3/4 plugs missing from home.device.registry (LOW)

### Tuya Bulb Reliability (2 gaps)
- GAP-OP-1084: bedroom_empress_bulb unavailable (HIGH)
- GAP-OP-1085: bedroom_king_bulb unavailable 3 days (HIGH)

### Systemic (3 gaps)
- GAP-OP-1086: No unified device health gate across protocols (HIGH)
- GAP-OP-1087: No automated device recovery (MEDIUM)
- GAP-OP-1089: Health cap coordinator IP wrong (LOW)

## Step 2: Physical Fixes (requires on-site)
- Re-pair TS0044 scene switch (rebuild database entry)
- Factory reset + recommission BILRESA via iPhone
- Check B6EE plug power/network
- Check bedroom bulb power/Wi-Fi at 10.0.0.63 and 10.0.0.64
- Add Zigbee router device in living room

## Step 3: Config Fixes (remote)
- Z2M: add availability tracking
- Z2M: fix hold automation
- Z2M: refresh devices snapshot
- Fix health cap coordinator IP
- Register TP-Link plugs in device registry
- Classify Matter devices in device map
- Rename King Lamp device for entity parity

## Step 4: Monitoring + Prevention
- Create unified device health gate (all protocols)
- Add database integrity check to Z2M health cap
- Create automated recovery automations

## Step 5: Network Hardening (deferred — requires full re-pair)
- Channel migration to 25/26
- Network key rotation
- Add Zigbee router hardware

## Success Criteria
- All 19 gaps resolved or deferred with justification
- Unified device health gate passing
- All everyday-use devices (buttons, plugs, bulbs) reliably available

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
