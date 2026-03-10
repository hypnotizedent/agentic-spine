---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: slash-command
---

# /fix - Guided Gap Workflow

Step-by-step gap lifecycle: file, claim, fix, verify, close.

## Arguments

- `$ARGUMENTS` — optional gap ID (e.g. `GAP-OP-280`) to resume an existing gap

## Actions

### If no gap ID provided (new gap):
1. Ask: what is the issue? (type, severity, description, related doc)
2. Determine next gap ID: check tail of `ops/bindings/operational.gaps.yaml`.
3. File the gap:
   ```
   ./bin/ops cap run gaps.file --id GAP-OP-<N> --type <type> --severity <severity> --description "<desc>" --discovered-by "<source>" --doc "<doc>"
   ```
   Valid types: stale-ssot, missing-entry, agent-behavior, unclear-doc, duplicate-truth, runtime-bug
   Valid severities: low, medium, high, critical

   **Loop linkage:** When filing a gap inside an active loop, set `--discovered-by` to the loop ID (e.g., `LOOP-<NAME>-<DATE>`). This links the gap to the loop for reconciliation tracking. To add explicit `parent_loop` linkage (for deferred gaps), manually edit the gap entry after filing.

4. Claim the gap:
   ```
   ./bin/ops cap run gaps.claim GAP-OP-<N> --action "<what you will do>"
   ```
5. Implement the fix.
6. Run `./bin/ops cap run spine.verify` — must pass.
7. Commit with prefix: `fix(GAP-OP-<N>): <description>`
8. Close the gap:
   ```
   echo "yes" | ./bin/ops cap run gaps.close GAP-OP-<N> --status fixed --fixed-in "<commit ref>"
   ```

### If gap ID provided (resume):
1. Check gap status in `ops/bindings/operational.gaps.yaml`.
2. If unclaimed, claim it first.
3. Continue from step 5 above.

## Key Rules
- `gaps.close` requires manual approval — pipe `echo "yes"` in scripts.
- `gaps.file` uses named args: `--id`, `--type`, `--severity`, `--description`, `--discovered-by`, `--doc`.
- `gaps.claim` uses positional GAP_ID first: `gaps.claim GAP-OP-XXX --action "desc"`.
- Never fix inline — always register the gap first, then fix through the registration.
