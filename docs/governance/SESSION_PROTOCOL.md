---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-07
scope: session-protocol
---

# Session Protocol

Agent entry is simple:

1. Open the repo.
2. Read [NORTH_STAR.md](/Users/ronnyworks/code/agentic-spine/NORTH_STAR.md), [SPINE.md](/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE.md), and this file.
3. Run:

```bash
cd ~/code/agentic-spine
./bin/ops status --json
./bin/ops verify --core-only
./bin/ops cap list
```

4. Work through `./bin/ops cap run <capability> -- ...`

## Desktop

- Use the CLI directly.
- Read only the files needed for the current task.
- Prefer `ops cap run` over ad hoc shell when a capability exists.
- Re-run `./bin/ops verify --core-only` after meaningful mutations.

## Remote Or Mobile

- If the repo and CLI are unavailable, say so plainly.
- Work from pasted command output or draft-only instructions.
- Do not claim anything was executed when you could not run it.

## Unknown Environment

- Do not mutate anything until you know whether the repo and CLI are available.
- Ask for `ops status --json` output or establish the repo context first.
