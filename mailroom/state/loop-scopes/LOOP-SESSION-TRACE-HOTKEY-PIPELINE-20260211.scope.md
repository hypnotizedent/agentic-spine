---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
---

# LOOP-SESSION-TRACE-HOTKEY-PIPELINE-20260211

> **Status:** active
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Severity:** high

---

## Executive Summary

Make hotkey-launched terminals (Ctrl+Shift+S/O/C) fully traceable and predictable.
Every terminal gets a session ID, auto-bootstrap, command telemetry, and governed
awareness of MCP state, agent routing, and capability surfaces. Single apply-owner
lock prevents multi-terminal proposal conflicts.

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Loop registration + scope | None | **DONE** |
| P1 | Session launcher script (`session-start <lane>`) | None | **DONE** |
| P2 | Auto-bootstrap (status, caps, rag health, gaps) | P1 | **DONE** |
| P3 | Command telemetry (zsh preexec logging) | P1 | **DONE** |
| P4 | Apply-owner lock (single-terminal proposals.apply) | P1 | **DONE** |
| P5 | RAG canonical-only ingest + drift gate (D68) | None | **DONE** |
| P6 | MCP/tooling awareness at session start | P2 | **DONE** |
| P7 | Hammerspoon integration (C/O bootstrap parity) | P1 | **DONE** |

---

## P1: Session Launcher

Create `ops/plugins/session/bin/session-start`:
- Accepts `<lane>` arg: `scan`, `apply`, `coordinator`
- Generates `SPINE_SESSION_ID` (format: `SES-<date>-<lane>-<short-hash>`)
- Writes `<id>.yaml` to `mailroom/state/sessions/`
- Exports `SPINE_SESSION_ID` and `SPINE_LANE` to env
- Logs lane, terminal ID, timestamp

## P2: Auto-Bootstrap

On session start, run and log:
- `./bin/ops status`
- `./bin/ops cap list`
- `ops cap run rag.health`
- `ops cap run gaps.status`
- Save outputs to `mailroom/state/sessions/<id>/bootstrap.log`

## P3: Command Telemetry

Add zsh `preexec` hook that logs:
- Timestamp, command, working directory
- Into `mailroom/state/sessions/<id>/commands.log`
- Source: `~/code/workbench/dotfiles/zsh/` or session-start injection

## P4: Apply-Owner Lock

- `proposals.apply` checks for `mailroom/state/apply-owner.lock`
- Lock contains session ID of the terminal that claimed apply ownership
- Only the apply-owner can run `proposals.apply`; all others get a clear error
- Lock acquired via `session-start apply` lane

## P5: RAG Canonical-Only Ingest

- Tighten RAG manifest filter: index only `status: authoritative|reference`
- Exclude `_audits/`, `_archived/`, `_imported/`, `status: historical|proposed`
- Add drift gate (D68) verifying RAG index contains only canonical docs

## P6: MCP/Tooling Awareness

At bootstrap, print summary:
- Agent routing table (from agents.registry.yaml)
- Governed capability count + deny domains
- MCP parity status (D66 result)

## P7: Hammerspoon Integration

Document integration points:
- Ctrl+Shift+S → `session-start scan`
- Ctrl+Shift+O → `session-start apply`
- Ctrl+Shift+C → `session-start coordinator`
- Hammerspoon config in workbench dotfiles

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| Every terminal has a session ID | `ls mailroom/state/sessions/` |
| Bootstrap outputs logged | `cat <session>/bootstrap.log` |
| Command telemetry working | `cat <session>/commands.log` |
| Apply-owner lock enforced | Second terminal gets error on proposals.apply |
| RAG indexes only canonical docs | D68 drift gate PASS |
| spine.verify green with D68 | ops cap run spine.verify |

---

_Scope created by: Terminal C (claude-opus-4.6), 2026-02-11_
