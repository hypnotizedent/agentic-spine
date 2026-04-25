---
status: authoritative
owner: "@operator"
last_verified: 2026-04-07
scope: spine-minimal-operating-contract
---

# SPINE.md - Minimal Operating Contract

The spine is a tool. Agent entry is AGENTS-first, then doc-first and CLI-first.

## Startup

Read [AGENTS.md]($SPINE_ROOT/AGENTS.md) first for the
current aperture and operator entry rules.

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach
./bin/ops status --json
./bin/ops verify
./bin/ops cap list
```

## Daily Use

- Read [AGENTS.md]($SPINE_ROOT/AGENTS.md) first for the current aperture.
- Read [NORTH_STAR.md]($SPINE_ROOT/NORTH_STAR.md) for platform identity.
- Read [SESSION_PROTOCOL.md]($SPINE_ROOT/docs/governance/SESSION_PROTOCOL.md) for environment behavior.
- Read [NODE_PROMOTION_LADDER.md]($SPINE_ROOT/docs/governance/NODE_PROMOTION_LADDER.md) when the question is how node roles become real.
- Use `./bin/ops cap run <capability> -- ...` when a capability exists.
- Keep changes bounded and re-run `./bin/ops verify` after meaningful mutations.

## Principle

If an agent cannot understand how to work here by reading the entry surface,
the doctrine docs, and running the three commands above, the entry surface is
too complex.
