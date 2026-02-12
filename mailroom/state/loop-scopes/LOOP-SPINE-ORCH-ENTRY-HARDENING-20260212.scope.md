---
status: active
owner: "@ronny"
created: 2026-02-12
---

# LOOP-SPINE-ORCH-ENTRY-HARDENING-20260212

> **Status:** active
> **Owner:** @ronny
> **Created:** 2026-02-12
> **Severity:** high

## Executive Summary

Harden orchestration terminal entry to prevent worker collision by default:
strict per-lane worktree resolution, strict launcher behavior, worker-branch-safe
pre-commit policy, and smoke coverage proving lane isolation.

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Baseline/receipts/snapshots | DONE |
| P1 | `orchestration-terminal-entry` capability + docs | DONE |
| P2 | `spine_terminal_entry.sh` strict capability default | DONE |
| P3 | Pre-commit guard (main protected, worker/* allowed) | DONE |
| P4 | Collision smoke tests + launcher sanity script | DONE |
| P5 | Hammerspoon strict-mode alignment + failure alerting | DONE |
| P6 | Recert and before/after evidence | DONE |

## Success Criteria

- Workers D/E/F/G resolve to distinct deterministic lane worktrees by default.
- Worker launch path cannot silently fall back to shared checkout.
- Main branch remains protected under multi-session mode.
- Orchestration validate->integrate path remains green.
- `spine.verify` and `gaps.status` pass at closeout.
