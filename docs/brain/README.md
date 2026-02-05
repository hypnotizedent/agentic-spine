# .brain/

<!-- ROUTING BLOCK (governance) -->
## Routing
- Navigation SSOT: [`docs/DOC_MAP.md`](../docs/DOC_MAP.md)
- Governance index: [`docs/governance/GOVERNANCE_INDEX.md`](../docs/governance/GOVERNANCE_INDEX.md)
- Global agent rules: [`docs/governance/SESSION_PROTOCOL.md`](../docs/governance/SESSION_PROTOCOL.md)

Agent memory and context system for the agentic-spine.

## Setup

```bash
.brain/setup.sh
```

One command. Sets up everything.

## Files

| File | Purpose | Auto-updated? |
|------|---------|---------------|
| `rules.md` | The 5 rules agents follow | No (edit manually) |
| `memory.md` | Cross-session learnings | Yes (Ctrl+9) |
| `context.md` | Generated at session start | Yes (auto) |
| `generate-context.sh` | Builds context.md | - |
| `setup.sh` | One-time setup | - |

## Hotkeys

| Key | Action |
|-----|--------|
| Ctrl+0 | Launch Claude (with context) |
| Ctrl+2 | Launch OpenCode (with context) |
| Ctrl+3 | Launch Codex (with context) |
| Ctrl+9 | Close session (save to memory) |
| Ctrl+R | Quick RAG query |

## How It Works

**Session start (Ctrl+0/2/3):**
1. `generate-context.sh` runs
2. Combines: rules + open issues + last handoff + memory
3. Writes to `context.md`
4. Prints to terminal
5. Agent launches

**Session end (Ctrl+9):**
1. Prompts for issue #, LEARNED, MISTAKE, PATTERN
2. Appends to `memory.md`
3. Next session picks it up

## Maintenance

**Monthly:** Trim memory.md to ~100 lines (keep recent, archive old).

That's it. No other maintenance needed.
