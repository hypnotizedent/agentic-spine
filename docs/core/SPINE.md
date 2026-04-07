---
status: deprecated
superseded_by: docs/governance/SPINE.md
deprecation_date: 2026-03-23
deprecation_trigger: SPINE-V3-CANONICALIZATION-WAVE3
retirement_reason: "Teaches legacy entry/startup workflow instead of canonical V3 attach"
---

# Agentic Spine (Deprecated)

> This document is retained for historical reference only.
>
> Canonical workflow/governance guidance lives in
> [`docs/governance/SPINE.md`](../governance/SPINE.md).
>
> Canonical V3 entry:
>
> `./bin/ops cap run session.v3.attach -- --allow-no-loop`

## Historical Reference

The content below describes an older detachable control-plane model and should
not be used as current workflow guidance.

Core is intentionally small: one CLI, one runtime, one receipt format.

Canonical CLI: `./bin/ops`

1) `./bin/ops preflight`         → print governance banner + service hints (safe)
2) `./bin/ops start loop <ID>`   → legacy worktree bootstrap pattern
3) `./bin/ops cap run <cap>`     → execute one governed capability (receipted)
4) `./bin/ops run --inline "..."`→ enqueue work into the mailroom (watcher processes)
5) `./bin/ops status`            → show current work (no silent TODOs)

Everything else is a plugin.
