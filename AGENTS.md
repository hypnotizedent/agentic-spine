# AGENTS.md - Agentic Spine Runtime Contract

> Auto-loaded by local coding tools.
> Canonical runtime: `/Users/ronnyworks/code/agentic-spine`
> Last verified: 2026-02-06

## Session Entry

1. Start in `/Users/ronnyworks/code/agentic-spine`.
2. Read `docs/governance/SESSION_PROTOCOL.md`.
3. Run `./bin/ops loops list --open`.
4. Execute work via `./bin/ops cap run <capability>` or `./bin/ops run ...`.

## Source-Of-Truth Contract

- Canonical governance/runtime: `/Users/ronnyworks/code/agentic-spine`
- Tooling workspace: `/Users/ronnyworks/code/workbench` (read/write tools only)
- Legacy workspace: `$LEGACY_ROOT` (read-only reference only)
- All governed receipts: `/Users/ronnyworks/code/agentic-spine/receipts/sessions`
- All runtime queues/logs/state: `/Users/ronnyworks/code/agentic-spine/mailroom/*`

## Hard Rules

1. No runtime commands from the legacy workspace.
2. No alternate queue, receipt, or watcher runtime outside spine mailroom.
3. No ungoverned home-root output sinks (`/Users/ronnyworks/*.log`, `*.out`, `*.err`).
4. Query before guessing: read the SSOT docs and use repo search (`rg`) before inventing answers. `mint ask` is deprecated.
5. Close loops with receipts as proof.

## Canonical Commands

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run spine.status
./bin/ops cap run spine.verify
./bin/ops loops list --open
```
