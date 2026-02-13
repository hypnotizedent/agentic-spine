# /gates - Gate Reference

List drift gates, filter by category, and show fix hints.

## Arguments

- `$ARGUMENTS` — optional: category name (e.g. "path-hygiene"), gate ID (e.g. "D42"), or "all"

## Actions

### List all gates:
Run `./bin/ops cap run spine.verify` and report all gate IDs with status.

### Filter by category:
If a category is specified, list only gates in that category:

| Category | Gates |
|----------|-------|
| path-hygiene | D30, D31, D42, D46, D47 |
| git-hygiene | D48, D62, D64 |
| ssot-hygiene | D54, D58, D59 |
| secrets-hygiene | D20, D25, D43, D55, D63, D70 |
| doc-hygiene | D16, D17, D27, D68, D84 |
| loop-gap-hygiene | D34, D61, D75, D83 |
| workbench-hygiene | D72, D73, D74, D77, D78, D79, D80 |
| infra-hygiene | D22, D23, D24, D35, D50, D51, D52, D69 |
| agent-surface-hygiene | D26, D32, D49, D56, D65, D66 |
| process-hygiene | D29, D33, D38, D53, D60, D67, D71, D81, D82 |

### Show gate details:
If a gate ID is specified (e.g. D42):
1. Read the gate script: `surfaces/verify/d<NN>-<name>.sh`
2. Extract the `# TRIAGE:` header for the fix hint.
3. Read the gate logic to explain what it checks.
4. Report: ID, name, category, what it checks, fix hint, affected files.

### Special notes:
- D1-D15: inline checks in `surfaces/verify/drift-gate.sh` (no separate script)
- D21: retired/reserved (merged into D56)
- Some gates run in verbose mode only (D25, D26, D32, D37, D39, D46)
- Composite gates (D55, D56, D57) replace verbose subchecks in default mode

## Output

Table format:
- `Gate ID` | `Name` | `Category` | `TRIAGE hint`
