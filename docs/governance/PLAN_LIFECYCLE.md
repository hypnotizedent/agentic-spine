---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-03
scope: plan-lifecycle
---

# Plan Lifecycle & Mutation Contract

> Canonical reference for deferred-intent plan lifecycle operations.
> Authority: `ops/bindings/planning.horizon.contract.yaml` (boundary_model.plan)
> Registry: `mailroom/state/plans/index.yaml`

## Overview

A **plan** is a deferred-intent container for work that is not yet ready for
active loop execution. Plans live in `mailroom/state/plans/index.yaml` and
follow a strict lifecycle with four terminal-aware statuses.

Plans are distinct from **loops** (active execution containers) and from
**step-sequence plans** (`docs/core/PLAN_SCHEMA.md`). This document covers
only the deferred-intent plan lifecycle.

## Plan Status Lifecycle

```
deferred  ──promote──>  promoted  ──retire──>  retired
    │                      │
    │                      └──cancel──>  canceled
    │
    ├──retire──>  retired
    └──cancel──>  canceled
```

### Statuses

| Status | Meaning | Terminal? |
|--------|---------|-----------|
| `deferred` | Intent captured; not yet ready for execution | No |
| `promoted` | Activated; loop horizon set to `now`, status set to `active` | No |
| `retired` | Intentionally shelved; historical intent preserved | Yes |
| `canceled` | Intentionally abandoned; no longer relevant | Yes |

### Transition Rules

| From | Allowed To |
|------|-----------|
| `deferred` | `promoted`, `retired`, `canceled` |
| `promoted` | `retired`, `canceled` |
| `retired` | (none — terminal state) |
| `canceled` | (none — terminal state) |

## Mutation Capabilities

### `planning.plans.create` (mutating, auto)

Creates a new deferred plan entry.

```bash
./bin/ops cap run planning.plans.create -- \
  --plan-id PLAN-MY-WORK \
  --loop-id LOOP-SOURCE-20260303 \
  --owner "@ronny" \
  --review-date 2026-03-16 \
  --description "What this plan intends to accomplish"
```

Required: `--plan-id`, `--loop-id` (or `--source-loop-id`), `--owner`, `--review-date`, `--description`
Optional: `--horizon`, `--activation-trigger`, `--depends-on-loop`, `--linked-gaps`, `--target-loop-id`

### `planning.plans.list` (read-only, auto)

Lists plans with optional filters.

```bash
./bin/ops cap run planning.plans.list
./bin/ops cap run planning.plans.list -- --json
./bin/ops cap run planning.plans.list -- --status deferred
./bin/ops cap run planning.plans.list -- --horizon later
```

### `planning.plans.promote` (mutating, auto)

Promotes a deferred plan to active execution. Sets the source loop's horizon
to `now` and status to `active`.

```bash
./bin/ops cap run planning.plans.promote -- \
  --plan-id PLAN-MY-WORK \
  --reason "Dependencies resolved, ready for execution"
```

Required: `--plan-id`
Optional: `--loop-id` (override target loop), `--readiness`, `--reason`

### `planning.plans.retire` (mutating, auto)

Retires a plan without deleting historical intent. Used when work is no longer
relevant but was valid when filed.

```bash
./bin/ops cap run planning.plans.retire -- \
  --plan-id PLAN-MY-WORK \
  --reason "Superseded by PLAN-BETTER-APPROACH"
```

Required: `--plan-id`, `--reason`

Audit fields set automatically:
- `retired_at_utc`: UTC timestamp
- `retired_by`: `SPINE_AGENT_ID` or `USER`
- `retired_from_status`: previous status (`deferred` or `promoted`)
- `retired_reason`: the provided reason

### `planning.plans.cancel` (mutating, auto)

Cancels a plan. Used when the intent is abandoned entirely.

```bash
./bin/ops cap run planning.plans.cancel -- \
  --plan-id PLAN-MY-WORK \
  --reason "Requirements changed; this work is no longer needed"
```

Required: `--plan-id`, `--reason`

Audit fields set automatically:
- `canceled_at_utc`: UTC timestamp
- `canceled_by`: `SPINE_AGENT_ID` or `USER`
- `canceled_from_status`: previous status (`deferred` or `promoted`)
- `canceled_reason`: the provided reason

## Enforcement

### D308: Planning Horizon Integrity

Drift gate D308 enforces:

1. No active loop may have `horizon: later` or `horizon: future`.
2. Plan statuses must be valid enum values (`deferred`, `promoted`, `retired`, `canceled`).
3. Retired plans must have `retired_at_utc` and `retired_reason`.
4. Canceled plans must have `canceled_at_utc` and `canceled_reason`.

### Index Schema

Each plan entry in `mailroom/state/plans/index.yaml`:

```yaml
- plan_id: PLAN-EXAMPLE
  source_loop_id: LOOP-SOURCE-20260303
  owner: "@ronny"
  horizon: later
  status: deferred
  activation_trigger: manual|dependency
  review_date: "2026-03-16"
  description: "What this plan intends."
  linked_gaps: [GAP-OP-NNN]
  migrated_at_utc: "2026-03-03T00:00:00Z"
  # Set on promote:
  promoted_at_utc: "..."
  promoted_by: "..."
  # Set on retire:
  retired_at_utc: "..."
  retired_by: "..."
  retired_reason: "..."
  retired_from_status: "..."
  # Set on cancel:
  canceled_at_utc: "..."
  canceled_by: "..."
  canceled_reason: "..."
  canceled_from_status: "..."
```

## Relationship to Loops

- A plan **references** a source loop (the loop that generated the deferred intent).
- Promoting a plan **activates** the referenced loop (sets horizon=now, status=active).
- Retiring or canceling a plan does **not** automatically close the source loop.
  The loop should be closed separately if it has no other active work.

## SSOT Files

- Plan registry: `mailroom/state/plans/index.yaml`
- Plan documents: `mailroom/state/plans/PLAN-*.md`
- Horizon contract: `ops/bindings/planning.horizon.contract.yaml`
