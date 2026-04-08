# Claude Code Adapter — Lean Entry

Agent entry is doc-first and CLI-first.

## Read First

1. `NORTH_STAR.md`
2. `docs/governance/SPINE.md`
3. `docs/governance/SESSION_PROTOCOL.md`

## Run First

```bash
cd ~/code/agentic-spine
./bin/ops status --json
./bin/ops verify
./bin/ops cap list
```

## Work Model

- Use `./bin/ops cap run <capability> -- ...` for repo and infrastructure work.
- Read only the files needed for the current task.
- Verify after mutations.
- If CLI access is unavailable, say so plainly and work from pasted output only.
