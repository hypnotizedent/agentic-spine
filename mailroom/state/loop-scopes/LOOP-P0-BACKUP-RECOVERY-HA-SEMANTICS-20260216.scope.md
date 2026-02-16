---
loop_id: LOOP-P0-BACKUP-RECOVERY-HA-SEMANTICS-20260216
status: closed
created_at: 2026-02-16T00:59:00Z
closed_at: 2026-02-16T01:45:00Z
owner: terminal-c
severity: high
---

# P0 Backup Recovery + HA Semantics

## Problem

Four P0 stability items identified from Vaultwarden E2E audit:

1. **VM 212/213 backup coverage gap** — vzdump artifacts MISSING for mint-data and mint-apps
2. **HA backup staleness** — app-home-assistant backup 107+ hours stale
3. **download-stack recovery** — exited/missing containers after power events
4. **HA health semantics mismatch** — services.health.status reports FAIL (curl_exit=22) for 401, while home.health.check correctly reports OK for HTTP 401

## Deliverables

- [x] VM 212/213 included in vzdump job with enabled backup inventory entries
- [x] HA app backup decommissioned with governance evidence (VM-level backup sufficient)
- [x] download-stack containers investigated — intentionally parked/stopped per media.services.yaml
- [x] services.health.status normalizes HA 401 as OK (matches home.health.check semantics)

## Acceptance Criteria

1. ✅ vzdump job VMIDs include 212, 213
2. ✅ app-home-assistant disabled in backup.inventory.yaml with decommission note
3. ✅ huntarr/slskd/tdarr/bazarr-dl confirmed intentionally parked/stopped
4. ✅ services-health-status shows home-assistant as OK (not FAIL)

## Gaps Filed & Closed

- GAP-OP-549: VM 212/213 backup coverage → FIXED (b77f4e5)
- GAP-OP-550: HA backup staleness → FIXED (b77f4e5)
- GAP-OP-551: download-stack exited containers → FIXED (intentional)
- GAP-OP-552: HA health semantics mismatch → FIXED (b77f4e5)

## Commits

- b77f4e5: fix(GAP-OP-549,GAP-OP-550,GAP-OP-552): P0 backup recovery + HA semantics
- 21d891d: fix(GAP-OP-549): mark fixed via gaps.close
- 20294c0: fix(GAP-OP-550): mark fixed via gaps.close
- 34824dc: fix(GAP-OP-552): mark fixed via gaps.close

## Run Keys

- CAP-20260216-005659__spine.verify__Rh4x123038
- CAP-20260216-005701__backup.status__R566q25289
- CAP-20260216-010324__backup.vzdump.vmid.set__Rvhjj55408
- CAP-20260216-010456__ha.backup.create__Rrfbm56521

