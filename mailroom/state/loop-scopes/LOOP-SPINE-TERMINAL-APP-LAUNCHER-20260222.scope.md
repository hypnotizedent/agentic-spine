---
loop_id: LOOP-SPINE-TERMINAL-APP-LAUNCHER-20260222
created: 2026-02-22
status: closed
closed: 2026-02-22
owner: "@ronny"
scope: spine
priority: medium
objective: Build a lane-aware terminal app launcher UI that lets Ronny pick a profile and auto-attach/start loops per terminal
---

# Loop Scope: LOOP-SPINE-TERMINAL-APP-LAUNCHER-20260222

## Objective

Build a lane-aware terminal app launcher UI that lets Ronny pick a profile and auto-attach/start loops per terminal

## Completed

- Created `ops/commands/terminal-launch.sh` with subcommands:
  - `list-lanes`: JSON output of lane profiles
  - `list-loops`: JSON output of open loops
  - `launch`: Launch terminal with lane + optional loop
- Added `ops terminal` CLI subcommand
- Added `spine.terminal.launch` capability
- Created Raycast scripts:
  - `spine-launcher.sh`: Full interactive picker (fzf-based)
  - `spine-control.sh`, `spine-execution.sh`, `spine-audit.sh`, `spine-watcher.sh`: Quick-launch per lane
  - `spine-attach-loop.sh`: Attach to loops
- Updated Hammerspoon with `Ctrl+Shift+P` hotkey for launcher

## Commits

- spine: `ff4985a` - feat(spine): add lane-aware terminal launcher
- workbench: `0a55a6f` - feat(dotfiles): add Raycast and Hammerspoon integration
