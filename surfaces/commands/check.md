# /check - Proactive Gate Check

Check if planned changes will violate any drift gates before making them.

## Arguments

- `$ARGUMENTS` — description of planned change (e.g. "add a new VM", "modify CLAUDE.md", "add capability")

## Actions

1. Parse the planned change description.
2. Identify which gates are relevant based on the change type:

| Change Type | Relevant Gates |
|-------------|----------------|
| New file/directory | D1 (top-level dirs), D7 (executable bounds), D17 (root allowlist) |
| Path references | D30 (active config), D42 (case lock), D47 (brain path), D78 (workbench path) |
| Governance docs | D27 (fact duplication), D58 (freshness), D60 (deprecation), D65 (briefing sync), D84 (index) |
| Capabilities | D63 (metadata), D67 (capability map) |
| Git operations | D48 (worktree), D62 (remote parity), D64 (authority), D75 (gap mutation) |
| Secrets/API | D20/D55 (readiness), D25 (CLI canonical), D43 (namespace), D63 (preconditions), D70 (deprecated alias) |
| Workbench | D72-D74, D77-D80 (workbench gates) |
| Agent surfaces | D26/D56 (entry surfaces), D49 (discovery), D65 (briefing sync), D66 (MCP parity) |
| Infrastructure | D35 (relocation), D54 (IP parity), D59 (completeness), D69 (VM creation) |
| Proposals | D83 (queue health) |
| RAG/docs | D68 (canonical-only) |

3. For each relevant gate, read its `# TRIAGE:` header from the script file.
4. Warn about potential violations with preventive guidance.
5. Optionally run `./bin/ops cap run spine.verify` to confirm current baseline.

## Output

Report:
- `Planned Change`: what you described
- `Gates at Risk`: list of potentially affected gates with IDs
- `Preventive Actions`: what to do to avoid violations
- `Current Baseline`: PASS/FAIL from spine.verify
