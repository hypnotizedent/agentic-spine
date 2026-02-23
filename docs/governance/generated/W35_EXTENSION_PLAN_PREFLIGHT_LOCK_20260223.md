---
status: generated
owner: "@ronny"
last_verified: 2026-02-23
scope: extension-transaction-autopilot
---

# W35 Extension Plan + Preflight Lock

## One-command flow

1. `./bin/ops cap run platform.extension.scaffold -- --type <site|workstation|business|service|mcp|agent> --target-id <id> --owner <owner> --loop-id <loop_id> --proposal-id <cp_id>`
2. `./bin/ops cap run platform.extension.bind -- --type <type> --target-id <id> --transaction-file <txn.yaml> --apply`
3. `./bin/ops cap run platform.extension.plan -- --transaction-file <txn.yaml>`
4. `./bin/ops cap run platform.extension.preflight -- --transaction-file <txn.yaml> --strict`
5. `./bin/ops cap run platform.extension.transition -- --transaction-file <txn.yaml> --to proposed --dry-run`
6. `./bin/ops cap run platform.extension.index.build`

## Required artifacts

For each transaction in status `proposed|approved|executed|closed`, the outbox must contain:

- `mailroom/outbox/extension-transactions/<transaction_id>/plan.yaml`
- `mailroom/outbox/extension-transactions/<transaction_id>/preflight.json`

`plan.yaml` required keys:

- `transaction_id`
- `type`
- `target_id`
- `status`
- `bindings_touched`
- `required_capabilities`
- `required_verifications`
- `cross_repo_surfaces`
- `generated_at`

`preflight.json` required keys:

- `transaction_id`
- `overall_status` (`pass|fail`)
- `checks[]` (`id`, `status`, `detail`)
- `generated_at`

Freshness windows:

- `proposed`: 72h max preflight age
- `approved|executed|closed`: 24h max preflight age
- `approved|executed|closed` also require `overall_status=pass`

## D179 fail modes

- missing outbox directory or missing `plan.yaml` / `preflight.json`
- missing required keys in plan/preflight artifacts
- stale preflight artifact beyond status window
- non-pass preflight for `approved|executed|closed`

## Remediation steps

1. Rebuild plan artifact:
   - `./bin/ops cap run platform.extension.plan -- --transaction-file <txn.yaml>`
2. Rebuild preflight artifact:
   - `./bin/ops cap run platform.extension.preflight -- --transaction-file <txn.yaml> --strict`
3. Rebuild transaction index:
   - `./bin/ops cap run platform.extension.index.build`
4. Re-run hygiene verify:
   - `./bin/ops cap run verify.pack.run hygiene-weekly`

## No partial onboarding rule

Transactions are not considered admission-ready beyond `proposed` unless plan and preflight artifacts are present, fresh, and contract-complete.
