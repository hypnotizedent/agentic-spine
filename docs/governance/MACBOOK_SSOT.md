---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-11
verification_method: live-workstation-config + spine/workbench launcher audit
scope: macbook-control-plane
---

# MACBOOK SSOT

This is the spine-facing fact surface for the operator MacBook.

Authority boundary:
- Identity, host naming, and Tailscale address remain canonical in `docs/governance/DEVICE_IDENTITY_SSOT.md`.
- Managed desktop configs and deeper operator mechanics live in `/Users/ronnyworks/code/workbench/dotfiles/macbook/README.md`.
- This spine doc exists so agent read surfaces and fact locks point at a real governed file instead of a dead path.

## Canonical Facts

| Property | Value |
|----------|-------|
| Canonical name | `macbook` |
| Tailscale IP | `100.85.186.7` |
| Role | Mobile workstation and spine control-plane entry host |
| Canonical launcher entry | `./bin/ops terminal launch ...` |
| Canonical watcher label | `com.ronny.agent-inbox` |
| Managed configs owner | `/Users/ronnyworks/code/workbench/dotfiles/macbook` |

## Managed Configs

<!-- BEGIN AUTO CONFIGS -->
| Config | Path | Desired Source | Status |
|--------|------|----------------|--------|
| `hammerspoon` | `/Users/ronnyworks/.hammerspoon` | `/Users/ronnyworks/code/workbench/dotfiles/hammerspoon/.hammerspoon` | `ok` |
| `raycast-scripts` | `/Users/ronnyworks/.raycast-scripts` | `/Users/ronnyworks/code/workbench/dotfiles/raycast` | `ok` |
| `codex-config` | `/Users/ronnyworks/.codex/config.toml` | `/Users/ronnyworks/code/workbench/dotfiles/codex/config.toml` | `ok` |
| `opencode-config` | `/Users/ronnyworks/.config/opencode/opencode.json` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/opencode.json` | `ok` |
| `opencode-instructions` | `/Users/ronnyworks/.config/opencode/OPENCODE.md` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/OPENCODE.md` | `ok` |
| `opencode-omo-config` | `/Users/ronnyworks/.config/opencode/oh-my-opencode.json` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/oh-my-opencode.json` | `ok` |
| `opencode-commands` | `/Users/ronnyworks/.config/opencode/commands` | `/Users/ronnyworks/code/workbench/dotfiles/opencode/commands` | `ok` |
<!-- END AUTO CONFIGS -->

## Hotkeys

The boring launch rule is one governed picker and one governed closeout path.
Direct ad hoc launcher hotkeys are retired.

<!-- BEGIN AUTO HOTKEYS -->
| Hotkey | Action | Source |
|--------|--------|--------|
| **Ctrl+Shift+P** | Canonical Ronny launcher picker (choose terminal character) | `~/.hammerspoon/` |
| **Ctrl+Shift+T** | Enqueue a mailroom task (optional prompt) + show watcher status | `~/.hammerspoon/` |
| **Ctrl+Shift+E** | Run governed session closeout (includes structured friction intake) | `~/.hammerspoon/` |
| **Ctrl+Shift+R** | Manual friction.reconcile trigger for current loop | `~/.hammerspoon/` |
<!-- END AUTO HOTKEYS -->

## Raycast Surfaces

All active Raycast launcher surfaces must call `./bin/ops terminal launch` or a
governed spine capability. Workbench wrappers are compatibility edges, not the
source of launcher policy.

<!-- BEGIN AUTO RAYCAST -->
| Tool | Script | Command |
|------|--------|---------|
| **Raycast** | `Claude Code` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --role solo --tool claude` |
| **Raycast** | `Codex Full Auto` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --role solo --tool codex` |
| **Raycast** | `OpenCode` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --role solo --tool opencode` |
| **Raycast** | `Spine Audit` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --lane audit --tool claude --terminal SPINE-AUDIT-01` |
| **Raycast** | `Spine Calendar Today` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" cap run calendar.operator.view` |
| **Raycast** | `Spine Comms Flush` | `cd /Users/ronnyworks/code/workbench && ./scripts/root/operator/communications-ops.sh retry --limit 10` |
| **Raycast** | `Spine Control` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --lane control --tool opencode --terminal SPINE-CONTROL-01` |
| **Raycast** | `Spine Execution` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --lane execution --tool opencode --terminal SPINE-EXECUTION-01` |
| **Raycast** | `Spine Launcher` | `"$OPS_BIN" terminal launch --role solo --tool "$default_tool" --terminal "$terminal_id"` |
| **Raycast** | `Spine Start Routine` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --role solo --tool verify` |
| **Raycast** | `Spine Watcher` | `"/Users/ronnyworks/code/agentic-spine/bin/ops" terminal launch --lane watcher --tool verify --terminal SPINE-WATCHER-01` |
<!-- END AUTO RAYCAST -->

