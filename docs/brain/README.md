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
| `memory.md` | Session handoff notes (append-only; optional) |
| `generate-context.sh` | Builds `context.md` from current spine state |
| `context.md` | Generated session context (runtime output; uncommitted) |
| `lessons/` | Historical lesson captures (reference only) |
| `_imported/` | Imported command context (reference only) |

## Lessons Lifecycle Policy

Brain lessons follow a governed lifecycle:

| Stage | Location | Freshness SLA | Action |
|-------|----------|---------------|--------|
| Active lesson | `docs/brain/lessons/` | 30 days | Review and update or graduate |
| Graduated | `docs/governance/` or `docs/core/` | Per D58 (21 days) | Promoted to authoritative doc |
| Archived | `docs/brain/lessons/.archive/` | None | Read-only reference |

### Rules

- **Freshness SLA:** Active lessons must be reviewed within 30 days of last update
- **Graduation triggers:** Lesson referenced by 3+ governance docs, or lesson content stabilized for 2+ weeks
- **Archive triggers:** Lesson superseded by authoritative doc, or stale >60 days without review
- **Mutation policy:** Any agent may add lessons; graduation requires operator approval

## Common Use

```bash
cd /Users/ronnyworks/code/agentic-spine
docs/brain/generate-context.sh
```
