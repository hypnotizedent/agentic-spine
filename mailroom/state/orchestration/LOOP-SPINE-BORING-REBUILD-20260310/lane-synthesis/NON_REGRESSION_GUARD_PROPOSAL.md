# Non-Regression Guard Proposal

## Guard 1: Root Allowlist

Fail any new top-level tracked path outside:
`bin/`, `ops/`, `docs/`, `surfaces/`, `fixtures/`, canonical entry stubs, and explicit governance metadata files.

## Guard 2: Runtime Write Block

Fail tracked additions under:
`mailroom/inbox/`, `mailroom/logs/`, `mailroom/outbox/`, `runtime/`, and runtime-state file patterns in `mailroom/state/` (`*.pid`, `*.lock`, `*.queue`, `*.cursor`, `*.ndjson`, `*.db`, `ledger.csv`, `*token*`).

## Guard 3: Evidence Write Block

Fail tracked additions under `receipts/**` and any evidence-only directories that remain temporarily inside `mailroom/state/`.

## Guard 4: Duplicate Truth Block

Fail new authoritative docs outside `docs/governance/` and `docs/core/`.
Explicitly flag `docs/CANONICAL/**`, extra `SPINE.md` copies, and gate scripts outside `surfaces/verify/`.

## Guard 5: Foundation Leak Block

Flag new runtime/plugin/product/operator source landing in spine hot paths when it belongs in the extracted foundation:
`ops/runtime/**`, `ops/engine/**`, non-core `ops/plugins/**`, `docs/product/**`, `docs/runbooks/**`, `docs/brain/**`, `ops/staged/**`, and governance-path product plans or operator checklists.

## Guard 6: Local Surface Block

Fail tracked changes to local/private files unless an operator decision explicitly allows them:
`.environment.yaml`, `.identity.yaml`, `.mcp.json`, `.claude/**`, `.spine/**`, root `STUB-*`.

## Guard 7: Qualification Baseline

Check the generated lane manifests and compare changed paths against their last accepted bucket. Any bucket change requires a linked loop/proposal and explicit justification.
