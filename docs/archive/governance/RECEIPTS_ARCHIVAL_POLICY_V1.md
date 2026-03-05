---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: receipts-archival-and-freshness
---

# Receipts Archival Policy V1

## Purpose

Define non-destructive archival guardrails for receipts and establish measurable
coverage/freshness expectations for the active receipts index.

## Retention Classes

### hot

- Active window: up to 14 days old.
- Activity expectation: at least 4 events in 30 days.
- Default handling: remain in `receipts/sessions/`.

### warm

- Age window: 15-90 days old.
- Activity expectation: at least 1 event in 30 days.
- Eligible for archival planning and approved migration waves.

### cold

- Age window: 91+ days old.
- Activity expectation: inactive or closed.
- Eligible for archival planning and approved migration waves.

## Exempt Classes

The following classes are exempt from standard archive movement and pruning:

- `compliance-critical`
- `release-cert`

## Archive Target Layout

Approved archival moves must use this deterministic layout:

- `receipts/archive/<retention_class>/<YYYY>/<MM>/<filename>`
- Preserve filename and file content exactly.

## Execution Mode

Default policy mode is non-destructive.

- No destructive pruning is allowed by default.
- Any execution wave that moves receipts requires explicit operator approval.
- Every execution wave must emit a migration receipt under
  `receipts/audits/migration/`.

## Coverage and Freshness Thresholds

Coverage checks compare `receipts/sessions/` against
`ops/plugins/evidence/state/receipt-index.yaml`.

- Coverage warn threshold: below 75.0%
- Coverage fail threshold: below 50.0%
- Watermark age warn threshold: above 24.0 hours
- Watermark age fail threshold: above 168.0 hours
- Missing entries warn threshold: above 5000
- Missing entries fail threshold: above 15000

Warnings are reportable but non-blocking. Fail thresholds are blocking for
policy lock gates.
