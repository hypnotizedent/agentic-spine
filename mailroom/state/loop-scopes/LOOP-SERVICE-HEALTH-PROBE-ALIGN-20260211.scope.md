---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-SERVICE-HEALTH-PROBE-ALIGN-20260211
severity: low
---

# Loop Scope: LOOP-SERVICE-HEALTH-PROBE-ALIGN-20260211

## Goal

Disable false-negative health probes for localhost-bound services so services.health.status reflects actual availability.

## Problem

Three services bind to 127.0.0.1 by design (reverse-proxied via Caddy/CF tunnel). External Tailscale IP probes always return REFUSED, polluting health status output.

| Service | Port Binding | Probe URL | Result |
|---------|-------------|-----------|--------|
| firefly-iii | 127.0.0.1:8090 | http://100.92.156.118:8090 | REFUSED |
| paperless-ngx | 127.0.0.1:8092 | http://100.92.156.118:8092 | REFUSED |
| slskd | 127.0.0.1:5030 | http://100.107.36.76:5030 | REFUSED |

## Fix

Set `enabled: false` on all three probes in `services.health.yaml` with notes documenting the localhost-bind reason and Docker health as authoritative.

## Follow-up

Low priority: implement `probe_via: ssh` or `probe_via: localhost` feature in the health status plugin so localhost-bound services can be probed via SSH tunnel instead of direct HTTP. Track as future enhancement, not a gap.

## Gaps

| Gap | Status | Description |
|-----|--------|-------------|
| GAP-OP-099 | **FIXED** | Stale probe semantics for localhost-bound services |
