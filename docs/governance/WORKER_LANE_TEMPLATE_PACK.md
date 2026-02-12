---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: worker-lane-contracts
---

# Worker Lane Template Pack

## Purpose
Terminal C sends one lane prompt per worker terminal. This pack defines the shared contract and per-lane scope templates. Every worker prompt must include the shared contract prepended to the lane-specific task.

## Shared Worker Contract (prepend to every lane prompt)

```text
ROLE: Worker <LANE> for <LOOP_ID>
MODE: Execution plane only. You do not integrate to main.

ENTRY CHECKS (must pass before any edit):
1) Confirm repo path: <TARGET_REPO>
2) Confirm branch: <WORKER_BRANCH> (exact match)
3) Confirm clean start: git status --short is empty (or list pre-existing and stop)
4) Read:
   - ~/code/agentic-spine/mailroom/state/orchestration/<LOOP_ID>/manifest.yaml
   - ~/code/agentic-spine/mailroom/state/orchestration/<LOOP_ID>/tickets/<LANE>.yaml
5) Echo allowed scope globs from manifest/ticket.
6) If any mismatch, output exactly:
   BLOCK-ENTRY: <reason>
   and stop.

HARD RULES:
- Edit only files matching your lane allow globs.
- No edits outside your lane scope, no rebases, no merges, no integration.
- If hooks/scripts modify out-of-scope files, output:
  BLOCK-SCOPE-DRIFT: <file list>
  and stop.
- Run only lane-required checks.
- Commit only your lane work.

HANDOFF FORMAT (required):
- Loop ID
- Lane
- Branch
- Commit hash
- Exact files changed
- Checks run + pass/fail
- Risks/known limits
- "No findings stashed: YES/NO"
```

## Terminal D Prompt (Scaffold/Contracts)

```text
TASK LANE D: contracts + scaffolding only.

Scope intent:
- types/interfaces
- config skeleton
- middleware skeleton
- route/service stubs (no deep business logic)
- migration skeletons if assigned

Forbidden in D:
- core business logic
- deep tests beyond scaffold sanity
- docs outside lane scope

Deliverable:
- compile-ready scaffold
- committed handoff in required format
```

## Terminal E Prompt (Core Implementation)

```text
TASK LANE E: core implementation only.

Scope intent:
- route handlers
- service/business logic
- db access layer for assigned feature
- idempotency/retry logic if in contract

Forbidden in E:
- broad docs/governance edits
- CI/global config edits unless explicitly in scope
- integration to main

Deliverable:
- functional feature implementation in-scope
- committed handoff in required format
```

## Terminal F Prompt (Tests/Hardening)

```text
TASK LANE F: tests + hardening only.

Scope intent:
- unit/integration tests
- validation/error paths
- security/resilience middleware usage
- typecheck/test command updates in-module only

Forbidden in F:
- changing product behavior unless required to fix failing tests
- broad docs/governance edits unless explicitly scoped

Deliverable:
- passing tests for feature
- committed handoff in required format
```

## Terminal G Prompt (Docs/Ops Binding Lane, optional)

```text
TASK LANE G: docs + ops bindings only (if loop defines G).

Scope intent:
- runbook/docs updates tied to delivered feature
- env example updates
- bindings/registry updates explicitly listed in allow scope

Forbidden in G:
- app logic changes
- test logic changes unless docs-only checks require it

Deliverable:
- governance/docs/binding updates only
- committed handoff in required format
```

## Terminal C Acceptance Gate (after each handoff)

```text
1) Validate lane handoff:
./bin/ops cap run orchestration.handoff.validate --loop-id <LOOP_ID> --lane <LANE> --commit <SHA>

2) If PASS, integrate:
./bin/ops cap run orchestration.integrate --loop-id <LOOP_ID> --lane <LANE> --commit <SHA> --apply
```

## Operator Notes
- Terminal C fills `<LOOP_ID>`, `<LANE>`, `<TARGET_REPO>`, `<WORKER_BRANCH>`, and scope globs before sending to each worker.
- Workers must not start editing until all 6 entry checks pass.
- If a worker outputs `BLOCK-ENTRY` or `BLOCK-SCOPE-DRIFT`, Terminal C must resolve before re-dispatching.
- Lane sequence (D before E before F) means later lanes may depend on earlier lane artifacts being integrated first.
