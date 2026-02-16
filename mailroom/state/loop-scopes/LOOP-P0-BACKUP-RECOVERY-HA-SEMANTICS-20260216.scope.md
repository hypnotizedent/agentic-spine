---
loop_id: LOOP-P0-BACKUP-RECOVERY-HA-SEMANTICS-20260216
status: active
created_at: 2026-02-16T00:59:00Z
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

- [ ] VM 212/213 included in vzdump job with enabled backup inventory entries
- [ ] HA app backup either fresh (<26h) or formally decommissioned with governance evidence
- [ ] download-stack containers running healthy (0 exited)
- [ ] services.health.status normalizes HA 401 as OK (matches home.health.check semantics)

## Acceptance Criteria

1. `./bin/ops cap run backup.status` shows OK for vm-212-mint-data-primary and vm-213-mint-apps-primary
2. `./bin/ops cap run backup.status` shows OK or no stale for app-home-assistant
3. `./bin/ops cap run media.service.status` shows 0 exited containers on download-stack
4. `./bin/ops cap run services.health.status` shows home-assistant as OK (not FAIL)
5. `./bin/ops cap run spine.verify` passes

## Gaps Filed

- GAP-OP-528: VM 212/213 backup coverage
- GAP-OP-529: HA backup staleness
- GAP-OP-530: download-stack exited containers
- GAP-OP-531: HA health semantics mismatch

## Commits

(To be filled during implementation)

## Run Keys

(To be filled during validation)
