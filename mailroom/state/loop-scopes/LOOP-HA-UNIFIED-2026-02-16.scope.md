# LOOP: HA Unified Commands

**Created:** 2026-02-16
**Status:** open
**Owner:** claude

## Problem

HA ecosystem has grown to 17 bindings, 36 capabilities, 12 drift gates — but:
- Refresh requires running 10+ separate snapshot commands
- No single command shows the full HA picture
- 45 orphan devices create noise in drift gates

## Scope

### A. ha.refresh — One command to refresh everything
Run all HA snapshot commands in sequence. Single capability that keeps all bindings fresh.

### B. ha.status — Unified HA dashboard
Show in one command:
- API health
- Automation/device/entity counts
- Z2M health summary
- Addon status (flag errors)
- Binding freshness (days since last snapshot)
- Open HA-related gaps

### C. Orphan device classification (future)
Add category field to orphans: native-integration, system-internal, needs-registry

### D. HA doc index (future)
Single HASS_INDEX.md routing table

## Success Criteria

1. `./bin/ops cap run ha.refresh` refreshes all 12 HA bindings in one command
2. `./bin/ops cap run ha.status` shows complete HA health picture
3. Drift gate failures reduced (freshness gates pass after ha.refresh)

## Files to Create/Modify

- `ops/plugins/ha/bin/ha-refresh` (new)
- `ops/plugins/ha/bin/ha-status` (new)
- `ops/capabilities.yaml` (register ha.refresh, ha.status)
- `ops/bindings/capability_map.yaml` (add mappings)
- `ops/plugins/MANIFEST.yaml` (add capabilities)

## Commit Prefix

`feat(LOOP-HA-UNIFIED):`
