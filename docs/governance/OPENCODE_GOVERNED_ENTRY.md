---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: opencode-entry-contract
---

# OpenCode Governed Entry Contract

## Purpose

Define the canonical launch contract for OpenCode so all entry surfaces route
through spine governance and use a single model/provider target.

## Canonical Runtime

- Code root: `/Users/ronnyworks/code`
- Spine runtime: `/Users/ronnyworks/code/agentic-spine`
- Workbench launcher: `/Users/ronnyworks/code/workbench/scripts/root/spine_terminal_entry.sh`

## Required Launch Path

All OpenCode launches must go through:

`spine_terminal_entry.sh --role <...> --tool opencode`

Direct launch/bypass from Hammerspoon or Raycast is forbidden.

## Required Model/Provider

- OpenCode model: `openai/glm-5`
- Provider base URL: `https://api.z.ai/api/paas/v4`
- API key source: `ZAI_API_KEY` (alias `Z_AI_API_KEY` allowed)
- Key injection source of truth: Infisical (via spine helper flow)

## Required Surfaces

- Hammerspoon hotkey `Ctrl+Shift+O` -> `launchSolo("opencode")`
- Raycast `opencode.sh` -> `spine_terminal_entry.sh --tool opencode`
- OpenCode config symlink target:
  `/Users/ronnyworks/code/workbench/dotfiles/opencode/opencode.json`

## Internal Governance Surface

OpenCode reads `OPENCODE.md` from `~/.config/opencode/` at session start (equivalent to
Claude's `CLAUDE.md` and Codex's `AGENTS.md`).

Canonical source: `workbench/dotfiles/opencode/OPENCODE.md`

Required sections (enforced by D73):
- **Worker Lane Contract**: entry checks, hard rules, scope constraints, handoff format
- **Solo Mode Contract**: commit policy, verify-before-commit, gap registration
- **BLOCK-ENTRY / BLOCK-SCOPE-DRIFT**: explicit stop behaviors for governance violations

Deploy: copy `workbench/dotfiles/opencode/OPENCODE.md` to `~/.config/opencode/OPENCODE.md`.

## Drift Enforcement

- D72 (`d72-macbook-hotkey-ssot-lock.sh`): launcher/doc/root drift lock
- D73 (`d73-opencode-governed-entry-lock.sh`): OpenCode model/entry lock + governance contract surface

