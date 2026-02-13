# Loop State SSOT

## Active Loop Source

The canonical source for **currently open loops** is:

    mailroom/state/open_loops.jsonl

This file is maintained by `ops loops` commands. If it has 0 entries, there are no active loops.

## Scope Files (Historical)

    mailroom/state/loop-scopes/LOOP-*.scope.md

Scope files are **created when a loop opens** and **updated when it closes** (status field changes to `closed`). They persist as historical records after loop completion. A scope file existing does NOT mean the loop is open — check the status field inside the scope file.

## Archived State

- `open_loops.jsonl.pre-consolidation` — snapshot before a bulk consolidation event
- `open_loops.jsonl.archived` — older archived state

These are not actively used. They exist for audit trail purposes.

## How Agents Should Check

```bash
# Check open loops:
./bin/ops loops list --open

# Or directly:
cat mailroom/state/open_loops.jsonl
```
