---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-14
scope: surveillance-platform
---

# SURVEILLANCE PLATFORM SSOT

## Authority

This document is the canonical surveillance-platform design surface for shop deployment under spine governance.

Primary dependencies:
- `ops/bindings/vm.lifecycle.yaml`
- `ops/bindings/infra.placement.policy.yaml`
- `ops/bindings/infra.storage.placement.policy.yaml`
- `ops/bindings/domains/surveillance/surveillance.topology.contract.yaml`
- `ops/bindings/domains/surveillance/surveillance.operating.model.contract.yaml`

## Canonical Decisions

1. Single Home Assistant instance (existing home HA) is authoritative.
2. Frigate/go2rtc deploy path is CPU-first and must be runnable without external GPU.
3. VM IDs are allocated by governed intake; planning docs must not hardcode IDs.
4. Home Assistant reaches Frigate directly over Tailscale; relay proxies are not part of canonical runtime.

## Runtime Topology (v1)

1. `surveillance-stack` VM
- Frigate + go2rtc runtime
- Shop camera ingest
- Event and recording retention policy

2. Home HA instance (existing)
- Consumes Frigate events
- Drives surveillance automations/notifications
- Hosts dashboard surfaces

## Capabilities

- `surveillance.stack.status` (read-only) — **REGISTERED AND LIVE**
  - Frigate process health, recording/detect/mqtt enabled state
  - camera online/offline counts
  - detector pipeline status (cpu)
  - recording disk pressure
  - NVR reachability, disk state, alarm state
  - MQTT integration state

- `surveillance.event.query` (read-only) — **PARKED** (no detection events while detect.enabled=false)
  - query events by camera/label/time range
  - return counts + latest matches

## Storage & Retention Policy

- Storage tier: `tank-vms` (ZFS zvol, dedicated non-boot disk)
- Data mount: `/srv/data/surveillance` (normalized from `/mnt/data` in 2026-03-19 wave)
- **Live posture (2026-04-14)**: watch-only minimal — recording disabled, recordings dir empty, retention claims are zero
- **Target after recording enabled** (100GB disk): ~1 day motion recordings, 14 day clips
- **Target after 2TB remediation**: 7 day motion recordings, 14 day clips
- Snapshots: disabled
- Frigate DB + recordings on dedicated data disk, never on boot volume.
- Authority: `ops/bindings/domains/surveillance/surveillance.topology.contract.yaml`

## HA Integration Authority

- Single HA instance: existing home HA (VM 100, proxmox-home)
- Direct Tailscale path: HA `100.67.120.1` -> Frigate `100.89.1.111:5000`
- **Live state (2026-04-14)**: INACTIVE — `mqtt.enabled=false` on Frigate, MQTT event pipeline not running
- **Target integration**: Frigate MQTT via home HA broker at `100.67.120.1:1883` (requires operator to enable mqtt.enabled + record.enabled)
- Automations: person/vehicle/after-hours detection in home HA (TARGET, not live — depends on detection + MQTT)
- Dashboard: `shop-surveillance` exists in HA but is effectively empty; Frigate UI is the current primary surface
- Ring doorbell live-view entity is present as `camera.ring_doorbell_live_view` and may be `idle` when no active stream is open.
- Authority: `ops/bindings/surveillance.topology.contract.yaml`

## Non-Blocking Future Enhancements

- GPU acceleration (optional)
- Multi-site surveillance federation
- Frigate+ semantic search

## Drift Rules

- No references to `shop-ha` as required runtime component.
- No references to Tesla P40/GPU as deployment blocker.
- No fixed VMID claims before intake/lifecycle allocation.
