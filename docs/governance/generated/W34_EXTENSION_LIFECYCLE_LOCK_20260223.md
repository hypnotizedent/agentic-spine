---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: w34-extension-lifecycle-lock
---

# W34 Extension Lifecycle Lock (2026-02-23)

Task: `SPINE-W34-EXTENSION-LIFECYCLE-LOCK-AND-INDEX-20260223`

## Transition Rules

| From | Allowed To |
|---|---|
| planned | proposed, blocked |
| proposed | approved, blocked |
| approved | executed, blocked |
| executed | closed, blocked |
| blocked | proposed, closed |

Transitions are enforced by `platform.extension.transition` and gate `D178`.

## Evidence Requirements By Status

- `proposed`: `loop_id`, `proposal_id`
- `approved`: all `required_homes.*.status` must be `ready`
- `executed`: `run_keys` must be non-empty
- `closed`: `verify_core_run_key`, `verify_pack_run_key`, `proposals_status_run_key`

## Index Schema And Usage

Index path:
- `mailroom/outbox/extension-transactions/extension-transactions.index.json`

Generated via:

```bash
./bin/ops cap run platform.extension.index.build
```

Required fields:
- `generated_at`
- `totals_by_status`
- `totals_by_type`
- `pending_homes`
- `stale_transactions`

Freshness policy:
- index must be <= 24h old when extension transactions exist.

## Operator Recovery For Blocked Transitions

1. Run transition dry-run for the intended move:

```bash
./bin/ops cap run platform.extension.transition -- \
  --transaction-file <path> \
  --to <target-status> \
  --dry-run
```

2. Resolve missing evidence (`loop_id`, `proposal_id`, `run_keys`, verify keys) or home binding gaps.
3. Rebuild index:

```bash
./bin/ops cap run platform.extension.index.build
```

4. Re-run hygiene weekly verify to confirm `D178` passes.
