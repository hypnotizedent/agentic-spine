---
loop_id: LOOP-HA-SSOT-CLEANUP-20260215
status: open
owner: claude-code
created: 2026-02-15
scope: HA SSOT baseline cleanup — 7 gaps from post-baseline audit
gaps:
  - GAP-OP-486  # 30 unknown entities triage
  - GAP-OP-487  # Orphaned .bak dashboard files
  - GAP-OP-488  # Orphaned command-center-v2-stage.yaml
  - GAP-OP-489  # Dashboard YAML backup capability
  - GAP-OP-490  # Wire ha.ssot.apply into weekly refresh
  - GAP-OP-491  # HACS update monitoring capability
  - GAP-OP-492  # 1 addon in error state (Vaultwarden)
---

# LOOP-HA-SSOT-CLEANUP-20260215

## Objective
Close 7 gaps discovered during HA SSOT baseline audit.

## Lanes

### Lane A — GAP-OP-486: Unknown Entity Triage
- Create `ha.entity.state.expected-unknown.yaml` allowlist (30 entries categorized)
- Update `ha-entity-state-baseline` to cross-ref expected-unknown (like expected-unavailable)
- Update `ha-ssot-baseline-build` to include expected/unexpected unknown counts

### Lane B — GAP-OP-489 + GAP-OP-491: New Capabilities
- `ha.dashboard.backup`: rsync YAML dashboard files from HA to spine infra dir
- `ha.hacs.updates.check`: query HACS repos for pending updates via SSH .storage

### Lane C — GAP-OP-490: Refresh Wiring
- Add `ha.ssot.apply` to `ha-baseline-refresh.sh` after baseline build

### Lane D — GAP-OP-487 + GAP-OP-488 + GAP-OP-492: Triage & Close
- GAP-OP-487: Document .bak files as orphaned, note cleanup action
- GAP-OP-488: Document staging file as orphaned, note cleanup action
- GAP-OP-492: Identify Vaultwarden error, document expected state

## Exit Criteria
- All 7 gaps closed
- Expected-unknown parity with expected-unavailable pattern
- 2 new capabilities registered
- Weekly refresh wired
