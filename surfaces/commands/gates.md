# /gates - Gate Reference

List drift gates, filter by category, and show fix hints.

## Arguments

- `$ARGUMENTS` — optional: category name (e.g. "path-hygiene"), gate ID (e.g. "D42"), or "all"

## Actions

### List all gates:
Run `./bin/ops cap run spine.verify` and report all gate IDs with status.

### Filter by category:
If a category is specified, list only gates in that category.
**Always read from registry at runtime** (do not use hardcoded lists):
```
yq -r '.categories[] | select(.id != "retired") | .id + ": " + .description' ops/bindings/gate.registry.yaml
```
To list gates in a specific category:
```
yq -r '[.gates[] | select(.category == "CATEGORY" and .retired != true) | .id] | join(", ")' ops/bindings/gate.registry.yaml
```

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
