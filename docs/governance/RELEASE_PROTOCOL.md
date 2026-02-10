---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: release-protocol
---

# Release Protocol (Canonical)

## Purpose

Cut a **sharable, predictable** spine version so:
- every agent starts from the same tip,
- governance docs match the current capability/gate surface,
- and there is a single-file artifact you can send/store (`.zip`).

## Release Definition

A release is valid when all are true:
- `./bin/ops preflight` returns `0` (no split-brain STOP).
- `./bin/ops cap run agent.session.closeout` runs (D61 freshness satisfied).
- `./bin/ops cap run spine.verify` PASS.
- `origin/main` equals `github/main` (D62 PASS).
- No stray codex worktrees (D48 PASS).
- `./bin/ops cap run spine.release.zip` produces an artifact in `mailroom/outbox/`.

## Versioning

- Use semver-style tags: `vMAJOR.MINOR.PATCH-<name>`.
- Until v1, increment MINOR for new contracts / capabilities, PATCH for fixes.

## Canonical Release Steps (Operator)

1. Ensure a clean starting state:
   - `cd /Users/ronnyworks/code/agentic-spine`
   - `./bin/ops ready`
2. Build the sharable artifact:
   - `./bin/ops cap run spine.release.zip`
3. Tag + push:
   - `git tag -a vX.Y.Z-<name> -m "spine: vX.Y.Z-<name>"`
   - `git push origin --tags`
   - `git push github --tags`

## Notes

- Release artifacts are **not** committed. They are written to `mailroom/outbox/`.
- Receipts (`receipts/sessions`) are runtime proof, not part of the sharable artifact.

