---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-22
scope: claude-entrypoint-shim
---

# Claude Entrypoint Shim

`~/.claude/CLAUDE.md` is a redirect surface only. It must not become a second
governance system.

## Required Behavior

- Point operators back to the spine repo governance docs.
- Use one public entry command:

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

- Treat `session.start` as the bootstrap subroutine beneath attach/launcher
  flows, not a second human-facing workflow.
- Never tell operators to run `session.start` and then separately run
  `session.v3.attach`.
- Keep path references lowercase under `~/code/...`.

## Redirect Contract

The shim should direct operators to:

1. `AGENTS.md` for the thin entry stub.
2. `docs/governance/SPINE.md` for the minimal operating contract.
3. `docs/governance/SESSION_PROTOCOL.md` only when deeper surface-specific
   session behavior is needed.

## Recovery / Diagnostics

Use these only when attach/bootstrap troubleshooting is explicitly needed:

- `./bin/ops cap run session.start full`
- `./bin/ops cap run session.start degraded`
