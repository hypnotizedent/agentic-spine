---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: claude-entrypoint-governance
---

# Claude Entrypoint Shim Contract

> **Purpose:** Define how `~/.claude/CLAUDE.md` and related Claude home-config files
> are governed so they remain redirect surfaces, not governance authorities.

## Shim Rule

`~/.claude/CLAUDE.md` is a **redirect surface**. It must:

1. Point agents to `AGENTS.md` and `docs/governance/SESSION_PROTOCOL.md` for all policy
2. Contain **no standalone governance headings** (Authority Order, Immutable Invariants, Operating Loop, Safety Defaults, What You Must Not Do)
3. Use only **lowercase canonical paths** (`/Users/ronnyworks/code/`, not `/Users/ronnyworks/code/`)

## Governed Claude Files

| File | Path | Policy |
|------|------|--------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | Redirect shim only (no governance sections) |
| ctx.md | `~/.claude/commands/ctx.md` | Lowercase paths, references to spine docs |
| settings.json | `~/.claude/settings.json` | Lowercase paths in Write allow patterns |
| settings.local.json | `~/.claude/settings.local.json` | Lowercase paths in Bash allow patterns |

## Brain Path Contract

Runtime scripts that inject agent context must reference `docs/brain/` (tracked in repo),
**not** `.brain/` (does not exist). The canonical brain location is:

```
$SPINE_REPO/docs/brain/
```

Scripts governed by this contract:
- `ops/runtime/inbox/launch-agent.sh`
- `ops/runtime/inbox/hot-folder-watcher.sh`
- `ops/runtime/inbox/close-session.sh`
- `docs/governance/SESSION_PROTOCOL.md`

## Enforcement

| Gate | Enforces |
|------|----------|
| D46 | Claude instruction source lock (shim compliance + path case) |
| D47 | Brain surface path lock (no `.brain/` in runtime scripts) |

## Related Documents

| Document | Relationship |
|----------|-------------|
| [SESSION_PROTOCOL.md](SESSION_PROTOCOL.md) | Session entry authority |
| [HOST_DRIFT_POLICY.md](HOST_DRIFT_POLICY.md) | Host drift governance |
| [CORE_LOCK.md](../core/CORE_LOCK.md) | Gate definitions |
| D32 | Codex instruction source lock (analogous) |
