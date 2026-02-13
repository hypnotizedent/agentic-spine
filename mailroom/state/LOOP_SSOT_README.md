# Loop State SSOT

## Active Loop Source

The canonical source for **currently open loops** is:

    mailroom/state/loop-scopes/LOOP-*.scope.md

Scope files are maintained by `ops loops` commands. The `status` field in each scope file's YAML frontmatter determines whether a loop is open (`active`, `draft`, `open`) or `closed`. A scope file existing does NOT mean the loop is open — check the status field.

If `open_loops.jsonl` is absent, treat as empty set (0 open loops). This file is deprecated and no longer written to. Its absence is normal and expected.

## Archived State

- `open_loops.jsonl.pre-consolidation` — snapshot before the scope-file migration
- `open_loops.jsonl.archived` — older archived state

These are not actively used. They exist for audit trail purposes only.

## How Agents Should Check

```bash
# Check open loops (canonical):
./bin/ops loops list --open

# Full status including gaps and inbox:
./bin/ops status
```
