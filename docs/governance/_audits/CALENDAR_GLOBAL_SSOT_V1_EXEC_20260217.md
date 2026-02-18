---
status: completed
owner: "@codex"
last_verified: 2026-02-17
scope: calendar-global-ssot-v1-exec
---

# CALENDAR_GLOBAL_SSOT_V1_EXEC_20260217

## Architecture Summary

Implemented a canonical Calendar Global SSOT v1 slice with six explicit layers:

1. infrastructure
2. automation
3. identity
4. personal
5. spine
6. life

Layer authority and direction are modeled in `ops/bindings/calendar.global.yaml`.

- External calendars are authoritative for `identity` and `personal`.
- Spine is authoritative for `infrastructure`, `automation`, and `spine`.
- Life layer is modeled as external-authoritative read integration.

Generated outputs are deterministic and read-only in v1:

- merged global ICS: `mailroom/outbox/calendar/calendar-global.ics`
- per-layer ICS: `mailroom/outbox/calendar/calendar-<layer>.ics`
- bridge summary index: `mailroom/outbox/calendar/calendar-index.json`

Determinism contract:

- UID policy: `sha1(layer|event_id|source_ref|summary|winner)`, scoped to `calendar.agentic-spine`
- DTSTAMP policy: fixed binding-derived value (`20260217T000000Z`)
- Stable event ordering by layer then event keys

Timezone handling:

- Default timezone `America/New_York`
- VTIMEZONE emitted for NY
- Daily summary (`/calendar/today`) computes date in configured timezone

## File Touch Map

### New bindings
- `ops/bindings/calendar.global.yaml`
- `ops/bindings/calendar.global.schema.yaml`

### New plugin
- `ops/plugins/calendar/bin/calendar-generate`
- `ops/plugins/calendar/bin/calendar-status`
- `ops/plugins/calendar/bin/calendar-sync-plan`
- `ops/plugins/calendar/tests/test-calendar-generate.sh`
- `ops/plugins/calendar/tests/test-calendar-status.sh`
- `ops/plugins/calendar/tests/test-calendar-sync-plan.sh`

### Registrations
- `ops/plugins/MANIFEST.yaml`
- `ops/capabilities.yaml`
- `ops/bindings/capability_map.yaml`

### Bridge read integration
- `ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve`
- `ops/bindings/mailroom.bridge.yaml`

## Capability Output Contracts

### `calendar.generate` (read-only)
- Input: `ops/bindings/calendar.global.yaml`
- Output: deterministic ICS artifacts + `calendar-index.json` under `mailroom/outbox/calendar/`
- No external API calls

### `calendar.status` (read-only)
- Validates binding structural expectations
- Reports generated artifact existence and freshness
- Supports JSON envelope with deterministic keys

### `calendar.sync.plan` (read-only)
- Outputs pull/push intent only (dry-run)
- References existing `graph.calendar.*` capability contracts
- Performs no mutating sync actions in v1

## Bridge Endpoint Contract

### `GET /calendar/feed` (auth required)
- Query: `layer=<all|infrastructure|automation|identity|personal|spine|life>`
- Default: `all`
- Returns ICS (`text/calendar`) from generated outbox artifacts

### `GET /calendar/today` (auth required)
- Returns compact JSON daily summary for agent/mobile consumption
- Source: `mailroom/outbox/calendar/calendar-index.json`
- Includes date/timezone, count, layer_counts, and compact event rows

## Verification Evidence

### Preflight lane (initial)
- `CAP-20260217-191607__stability.control.snapshot__Rfjnt59489`
- `CAP-20260217-191654__verify.core.run__Regwt64509`
- `CAP-20260217-191737__verify.domain.run__Rra2s77480` (`aof --force`)
- `CAP-20260217-191751__verify.domain.run__Rp6b383804` (`ms-graph --force`)
- `CAP-20260217-191829__proposals.status__Rk0fb91795`
- `CAP-20260217-191832__gaps.status__Rtreg92341`

### Recovery baseline + cert lane
- `CAP-20260217-194346__verify.core.run__Rsotg22217` (post-baseline recovery)
- Full Phase 4 lane run keys are recorded in session receipts and referenced in final report.

### Plugin tests
- `ops/plugins/calendar/tests/test-calendar-generate.sh` PASS
- `ops/plugins/calendar/tests/test-calendar-status.sh` PASS
- `ops/plugins/calendar/tests/test-calendar-sync-plan.sh` PASS

## Infra/HA Mutation Statement

Active infrastructure and HA execution surfaces were not mutated by this calendar slice.

Specifically not modified:

- `ops/bindings/operational.gaps.yaml`
- `mailroom/state/loop-scopes/*`
- `ops/bindings/gate.execution.topology.yaml`
- `ops/bindings/gate.domain.profiles.yaml`

No mutating HA runtime capability or active infra execution topology changes were introduced.
