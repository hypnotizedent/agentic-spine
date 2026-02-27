---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: spine-schema-normalization
---

# Spine Schema Conventions

Canonical conventions contract:

- `/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.schema.conventions.yaml`

## What It Standardizes

- Status/lifecycle vocabulary for binding files.
- Canonical field names (`id`, `description`, `created_at`, `updated_at`, `closed_at`).
- Disallowed legacy alias keys (`vmid`, `notes`, `discovered_at`, `opened`).
- ISO-8601 date format validation.

## Enforcement Model

- Gate: `D129` (`spine-schema-conventions-lock`)
- Script: `/Users/ronnyworks/code/agentic-spine/surfaces/verify/d129-spine-schema-conventions-lock.sh`
- Validator: `/Users/ronnyworks/code/agentic-spine/ops/plugins/verify/bin/schema-conventions-audit`

The lock uses **touch-and-fix** policy:

1. Existing legacy fields can remain only where explicitly excepted.
2. If an excepted file is modified, legacy aliases become blocking violations.
3. New/changed binding files must conform to conventions.

## Operator Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run schema.conventions.audit
./bin/ops cap run verify.domain.run aof
```

`schema.conventions.audit` writes a report to:

- `/Users/ronnyworks/code/agentic-spine/receipts/audits/governance/SPINE_SCHEMA_CONVENTIONS_AUDIT_<YYYYMMDD>.md`
