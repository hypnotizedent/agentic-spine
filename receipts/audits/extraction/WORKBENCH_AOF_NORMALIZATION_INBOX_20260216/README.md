# Workbench AOF Normalization Inbox (2026-02-16)

Purpose: collect parallel read-only findings from 3 OpenCode terminals, then synthesize one canonical implementation plan.

## Write Contract

- Lane A writes only: `L1_BASELINE_SURFACES.md`
- Lane B writes only: `L2_RUNTIME_DEPLOYMENT.md`
- Lane C writes only: `L3_SECRETS_CONTRACTS.md`
- Optional command evidence: `EVIDENCE_<LANE>.txt`

## Finding Format (required)

Use this block for each finding:

```md
### [P0|P1|P2] <short-title>
- Surface: <cluster>
- Problem: <1 sentence>
- Impact: <1 sentence>
- Evidence:
  - /absolute/path/file.ext:line
  - /absolute/path/file.ext:line
- Canonical rule (expected): <what "right" looks like>
- Recommended normalization: <small deterministic change>
```

## Scope

- Repo target: `/Users/ronnyworks/code/workbench`
- Cross-check references allowed in `/Users/ronnyworks/code/agentic-spine` only when needed for parity.
- No edits/fixes in this inbox pass.
