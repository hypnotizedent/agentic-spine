---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: slash-command
---

# /check - Proactive Gate Check

Check if planned changes will violate any drift gates before making them.

## Arguments

- `$ARGUMENTS` — description of planned change (e.g. "add a new VM", "modify CLAUDE.md", "add capability")

## Actions

1. Parse the planned change description.
2. Identify which gates are relevant by querying the registry:
   ```
   yq -r '.gates[] | select(.category == "CATEGORY") | .id + " " + .name + " — " + .description' ops/bindings/gate.registry.yaml
   ```
   Map the change type to a category:
   - New file/directory → `path-hygiene`
   - Path references → `path-hygiene`
   - Governance docs → `doc-hygiene`, `process-hygiene`
   - Capabilities → `process-hygiene`
   - Git operations → `git-hygiene`
   - Secrets/API → `secrets-hygiene`
   - Workbench → `workbench-hygiene`
   - Agent surfaces → `agent-surface-hygiene`
   - Infrastructure → `infra-hygiene`, `ssot-hygiene`
   - Proposals → `process-hygiene` (D83)
   - Loops/gaps → `loop-gap-hygiene`
3. For each relevant gate, read its fix_hint from registry:
   ```
   yq -r '.gates[] | select(.id == "DNN") | .fix_hint' ops/bindings/gate.registry.yaml
   ```
   Or read the `# TRIAGE:` header directly from the script file.
4. Warn about potential violations with preventive guidance.
5. Optionally run `./bin/ops cap run spine.verify` to confirm current baseline.

## Output

Report:
- `Planned Change`: what you described
- `Gates at Risk`: list of potentially affected gates with IDs
- `Preventive Actions`: what to do to avoid violations
- `Current Baseline`: PASS/FAIL from spine.verify
