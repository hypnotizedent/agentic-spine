---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
scope: spine-timeline-runbook
---

# Spine Timeline Runbook

## Purpose

Provides a normalized event timeline over receipts, loop scopes, gaps, handoffs, orchestration,
and proposal state, plus report generation to runtime audits.

Capabilities:
- `spine.timeline.query` (read-only)
- `spine.timeline.report` (mutating report writer)

Schema authority:
- `ops/bindings/spine.timeline.event.schema.yaml`

Canonical event fields:
- Required: `id`, `created_at`, `event_type`, `subject_type`, `subject_id`, `status`, `loop_id`, `capability`, `source_path`, `summary`
- Optional: `severity`, `actor_id`

## Source Authority Split

Repo-authoritative:
- `receipts/sessions`
- `mailroom/state/loop-scopes`
- `ops/bindings/operational.gaps.yaml`

Runtime-authoritative:
- `${SPINE_STATE}/ledger.csv`
- `${SPINE_STATE}/handoffs`
- `${SPINE_STATE}/orchestration`
- `${SPINE_OUTBOX}/proposals`
- `${SPINE_OUTBOX}/audits`

## Query Flow

`spine.timeline.query` is index-first for scale:
1. Reads `ops/plugins/evidence/state/receipt-index.yaml`.
2. Reads repo/runtime state surfaces.
3. Scans raw receipts only when `--scan-receipts` is requested.

Examples:
```bash
./bin/ops cap run spine.timeline.query --since 24h --timezone America/Los_Angeles
./bin/ops cap run spine.timeline.query --loop-id LOOP-EXAMPLE-20260218 --format json
```

## Report Flow

`spine.timeline.report` writes markdown/json reports under `${SPINE_OUTBOX}/audits` by default.
Writes are atomic and idempotent for deterministic concurrent execution.

Examples:
```bash
./bin/ops cap run spine.timeline.report --since 24h --report-id timeline-daily
./bin/ops cap run spine.timeline.report --since 7d --format json --output audits/timeline-weekly
```

Governance:
- `spine.timeline.report` is mutating.
- In multi-terminal sessions, writer-lane only (`proposals.submit` -> `proposals.apply`).
