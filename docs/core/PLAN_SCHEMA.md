# Plan Schema (Authoritative)

A plan is a sequential list of steps to be executed by agents.

## Format (YAML)

```yaml
plan_id: <unique identifier>
created: <ISO8601 timestamp>
goal: <one-line outcome statement>
steps:
  - id: <step identifier>
    agent: <agent name or "human">
    input_paths:
      - <path to input file or artifact>
    expected_outputs:
      - <path to expected output>
    on_fail: <stop|skip|retry N>
    timeout_sec: <max seconds, default 300>
```

## Required Fields

| Field | Required | Description |
|-------|----------|-------------|
| `plan_id` | yes | Unique identifier for the plan |
| `steps` | yes | Array of step objects |
| `steps[].id` | yes | Step identifier (unique within plan) |
| `steps[].agent` | yes | Agent to execute step |
| `steps[].on_fail` | yes | Failure behavior |

## Example Plan (2 steps)

```yaml
plan_id: KERNEL_HARDEN_20260203
created: 2026-02-03T00:30:00Z
goal: Add missing kernel contracts and verify gate
steps:
  - id: create_contracts
    agent: claude
    input_paths:
      - docs/RECEIPTS_CONTRACT.md
    expected_outputs:
      - docs/AGENT_OUTPUT_CONTRACT.md
      - docs/PLAN_SCHEMA.md
    on_fail: stop
    timeout_sec: 120

  - id: verify_contracts
    agent: ops
    input_paths:
      - surfaces/verify/contracts-gate.sh
    expected_outputs:
      - receipts/sessions/*/receipt.md
    on_fail: stop
    timeout_sec: 60
```

## Validation

Plans are validated by the orchestrator before execution.
