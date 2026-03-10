---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: slash-command
---

# /triage - Drift Gate Failure Triage

Diagnose and resolve a drift gate failure.

## Arguments

- `$ARGUMENTS` — optional gate ID (e.g. `D42`) or full failure output

## Actions

1. If no gate specified, run `./bin/ops cap run spine.verify` to identify failures.
2. For each failing gate:
   a. Read the gate script: `surfaces/verify/d<NN>-<name>.sh`
   b. Extract the `# TRIAGE:` header for the fix hint.
   c. Read the gate logic to understand what it checks.
   d. Identify the specific file(s) causing the failure from the output.
3. Apply the fix based on the triage hint.
4. Re-run `./bin/ops cap run spine.verify` to confirm the fix.
5. If the fix requires a gap registration, use `/fix` workflow.

## Gate Script Locations
- Inline gates (D1-D15): embedded in `surfaces/verify/drift-gate.sh`
- Delegated gates (D16-D84): individual scripts in `surfaces/verify/d<NN>-*.sh`
- D21 is retired/reserved (merged into D56)

## Output

Report:
- `Gate ID`: the failing gate
- `What it checks`: one-line description
- `Why it failed`: specific violation found
- `Fix`: actionable steps from TRIAGE hint
- `Verification`: spine.verify PASS confirmation
