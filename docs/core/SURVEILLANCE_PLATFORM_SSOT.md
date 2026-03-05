---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-04
scope: surveillance-platform
---

# SURVEILLANCE PLATFORM SSOT

## Authority

This document is the canonical surveillance-platform design surface for shop deployment under spine governance.

Primary dependencies:
- `docs/governance/CAMERA_SSOT.md`
- `ops/bindings/vm.lifecycle.yaml`
- `ops/bindings/infra.placement.policy.yaml`
- `ops/bindings/infra.storage.placement.policy.yaml`

## Canonical Decisions

1. Single Home Assistant instance (existing home HA) is authoritative.
2. Frigate/go2rtc deploy path is CPU-first and must be runnable without external GPU.
3. VM IDs are allocated by governed intake; planning docs must not hardcode IDs.

## Runtime Topology (v1)

1. `surveillance-stack` VM
- Frigate + go2rtc runtime
- Shop camera ingest
- Event and recording retention policy

2. Home HA instance (existing)
- Consumes Frigate events
- Drives surveillance automations/notifications
- Hosts dashboard surfaces

## Capability Targets (to register)

- `surveillance.stack.status` (read-only)
  - Frigate process health
  - camera online/offline counts
  - detector pipeline status (cpu)
  - recording disk pressure

- `surveillance.event.query` (read-only)
  - query events by camera/label/time range
  - return counts + latest matches

- `ha.surveillance.status` (read-only)
  - home HA integration health for surveillance entities/automations

## Non-Blocking Future Enhancements

- GPU acceleration (optional)
- Multi-site surveillance federation
- Frigate+ semantic search

## Drift Rules

- No references to `shop-ha` as required runtime component.
- No references to Tesla P40/GPU as deployment blocker.
- No fixed VMID claims before intake/lifecycle allocation.
