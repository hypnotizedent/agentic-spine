---
loop_id: LOOP-HA-AGENT-TOOLING-GAPS-20260228
created: 2026-02-28
status: closed
owner: "@ronny"
scope: ha
priority: medium
objective: Close HA agent tooling friction: no addon log cap, Z2M config not in SSOT, snapshot misses advanced config, SLZB API undocumented, no entity state query cap, SSH docker permission broken. These gaps made the HA device reliability audit 3x harder than necessary.
---

# Loop Scope: LOOP-HA-AGENT-TOOLING-GAPS-20260228

## Objective

Close HA agent tooling friction: no addon log cap, Z2M config not in SSOT, snapshot misses advanced config, SLZB API undocumented, no entity state query cap, SSH docker permission broken. These gaps made the HA device reliability audit 3x harder than necessary.

## Step 1: Gap Registration (COMPLETE)

Discovered during forensic audit of HA device reliability (LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228).

### Linked Gaps
- GAP-OP-1102: HA SSH hassio user cannot access docker API (HIGH)
- GAP-OP-1103: No ha.addon.logs capability — 401 on ha apps logs (HIGH)
- GAP-OP-1104: Z2M configuration.yaml advanced block not in SSOT (MEDIUM)
- GAP-OP-1105: ha.z2m.devices.snapshot misses advanced config (MEDIUM)
- GAP-OP-1106: SLZB-06/06MU coordinator API undocumented (LOW)
- GAP-OP-1107: No ha.entity.state.query capability (MEDIUM)

### Also linked (filed under LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT)
- GAP-OP-1101: gaps.file --batch yq if/then/else broken on v4.50.1 (HIGH)

## Step 2: Fix SSH + Addon Access
- Resolve docker group or Supervisor API auth for hassio user
- Create ha.addon.logs cap with authenticated Supervisor API

## Step 3: Extend Z2M Snapshot
- Capture advanced config block into z2m.config.yaml or z2m.network.yaml binding
- Include channel, availability, adapter, serial port, network_key hash

## Step 4: New Capabilities
- ha.entity.state.query — pattern-based entity state lookup with auto-auth
- ha.coordinator.status — SLZB-06 /config API query (optional)

## Success Criteria
- Agents can pull Z2M addon logs via cap
- Z2M advanced config has a SSOT binding
- Entity state queries don't require manual curl + auth dance

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
