---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: orchestration-capability
---

# Orchestration Capability

## Purpose

`orchestration.*` moves loop handoff and integration from prompt conventions to machine checks.

Capabilities:
- `orchestration.loop.open`
- `orchestration.ticket.issue`
- `orchestration.handoff.validate`
- `orchestration.integrate`
- `orchestration.loop.close`
- `orchestration.status`

## State Location

Per-loop state lives at:

`mailroom/state/orchestration/<loop-id>/`

Required manifest path:

`mailroom/state/orchestration/<loop-id>/manifest.yaml`

Manifest schema reference:

`ops/plugins/orchestration/manifest.schema.yaml`

## Manifest Contract

Required keys:
- `loop_id`
- `repo`
- `base_sha`
- `apply_owner`
- `lanes`
- `allow`
- `forbid`
- `checks`
- `sequence`

Example:

```yaml
loop_id: LOOP-SPINE-ORCH-EXAMPLE
repo: "/Users/ronnyworks/code/agentic-spine"
base_sha: c476ae1...
apply_owner: "ronnyworks"
status: open
lanes:
  worker-h:
    id: worker-h
    branch: worker/spine-orchestration-capability-phase1
    worker: worker-h
    status: ticket-issued
allow:
  worker-h:
    - ops/plugins/orchestration/**
    - ops/capabilities.yaml
forbid:
  - docs/legacy/**
  - ops/bindings/secrets.*
checks:
  worker-h:
    - ops/plugins/orchestration/tests/orchestration-smoke.sh
sequence:
  - worker-h
created_at: 2026-02-12T13:00:00Z
updated_at: 2026-02-12T13:05:00Z
```

## Lane Policy Examples

Example lane set:

```yaml
allow:
  api-lane:
    - ops/plugins/orchestration/**
  docs-lane:
    - docs/governance/ORCHESTRATION_CAPABILITY.md
forbid:
  - ops/bindings/ssh.targets.yaml
  - ops/bindings/secrets.*
sequence:
  - api-lane
  - docs-lane
```

Meaning:
- `api-lane` validates first.
- `docs-lane` cannot validate or integrate until `api-lane` is validated/integrated.
- Any touch to `ops/bindings/ssh.targets.yaml` or `ops/bindings/secrets.*` is rejected.

## Enforcement: handoff.validate

`orchestration.handoff.validate` enforces:
- commit exists
- commit is on the assigned lane branch
- commit descends from manifest `base_sha`
- every changed file matches lane allowlist
- no changed file matches forbid patterns
- prior lanes in `sequence` already validated or integrated

On pass it writes:
- `mailroom/state/orchestration/<loop-id>/validations/<lane>.yaml`
- `mailroom/state/orchestration/<loop-id>/artifacts/validate-<lane>-<ts>.md`

## Enforcement: integrate

`orchestration.integrate` enforces:
- only `apply_owner` can run `--apply`
- current branch must be `main`
- working tree/index must be clean
- lane has a validated record
- requested commit equals validated commit
- prior lanes in `sequence` are already integrated

Execution model:
- default mode: dry-run
- apply mode: `--apply`
- prints exact git operations before running
- uses `git cherry-pick -x --no-commit <validated_commit>`
- runs lane checks after cherry-pick, before commit
- writes integration record and artifact

Artifacts:
- `mailroom/state/orchestration/<loop-id>/integrations/<lane>.yaml`
- `mailroom/state/orchestration/<loop-id>/artifacts/integrate-<lane>-<ts>.md`

## Common Failure Cases

- Wrong branch:
  - `ERROR: wrong branch: commit is not on assigned branch ...`
- Base SHA mismatch:
  - `ERROR: base_sha mismatch: commit does not descend from ...`
- Forbidden file touched:
  - `ERROR: forbidden file touched: <path>`
- Out of sequence:
  - `ERROR: out-of-sequence: validate <lane-a> before <lane-b>`
  - `ERROR: out-of-sequence: integrate <lane-a> before <lane-b>`
- Wrong apply owner:
  - `ERROR: apply-owner only: expected '...', got '...'`
- Not on main:
  - `ERROR: must run from main (current: ...)`

## Smoke Tests

Run:

```bash
ops/plugins/orchestration/tests/orchestration-smoke.sh
```

Covered cases:
- wrong branch rejected
- base_sha mismatch rejected
- forbidden file touch rejected
- out-of-sequence rejected
- happy path validate + integrate
