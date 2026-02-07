# docs/brain

> **Status:** reference
> **Last verified:** 2026-02-07

Reference surface for session context generation and operating rules.

## Routing

- Governance entrypoint: [`../governance/SESSION_PROTOCOL.md`](../governance/SESSION_PROTOCOL.md)
- Governance index: [`../governance/GOVERNANCE_INDEX.md`](../governance/GOVERNANCE_INDEX.md)

## Runtime Contract

- `docs/brain` supports context loading and operator ergonomics.
- Canonical governance authority remains `docs/core/**` + `docs/governance/**`.
- `context.md` is generated runtime output and should remain uncommitted.

## Files

| File | Purpose |
|------|---------|
| `rules.md` | Session rule summary used by context loaders |
| `generate-context.sh` | Builds `context.md` from current spine state |
| `lessons/` | Historical lesson captures (reference only) |
| `_imported/` | Imported command context (reference only) |

## Common Use

```bash
cd /Users/ronnyworks/code/agentic-spine
docs/brain/generate-context.sh
```
