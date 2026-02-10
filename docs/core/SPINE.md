# Agentic Spine (Detachable)

> **Status:** authoritative
> **Last verified:** 2026-02-10

Core is intentionally small: one CLI, one runtime, one receipt format.

Canonical CLI: `./bin/ops`

1) `./bin/ops preflight`         → print governance banner + service hints (safe)
2) `./bin/ops start loop <ID>`   → create a loop-scoped worktree (no main drift)
3) `./bin/ops cap run <cap>`     → execute one governed capability (receipted)
4) `./bin/ops run --inline "..."`→ enqueue work into the mailroom (watcher processes)
5) `./bin/ops loops list --open` → show current work (no silent TODOs)

Everything else is a plugin.
