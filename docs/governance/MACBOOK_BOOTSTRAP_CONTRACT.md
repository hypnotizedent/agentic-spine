---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: macbook-bootstrap-contract
---

# MacBook Bootstrap Contract

## Purpose

Single authoritative surface defining what a fresh Mac needs to reach spine-ready state.
All bootstrap execution flows through spine capabilities with receipt-backed governance.

## Ownership Boundaries

| Layer | Owner | Responsibility |
|-------|-------|----------------|
| Spine capability | `host.macbook.bootstrap` | Mutating execution, receipts, approval gate, idempotency |
| Spine capability | `host.macbook.managed_configs.apply` | Symlink enforcement, Claude entrypoint, hotkey docs |
| Spine capability | `host.macbook.drift.check` | Read-only drift verification |
| Workbench scripts | `dotfiles/install.sh` | Implementation helper (git config, shell aliases, CLI tools) |
| Workbench scripts | `scripts/root/setup-mac-tools.sh` | Implementation helper (productivity app installs) |

**Rule:** Workbench scripts are internal helpers only. They MUST NOT be invoked directly
for bootstrap purposes. All bootstrap execution enters through `host.macbook.bootstrap`.

## Bootstrap Requirements

### Phase 1: Core CLI Tools

These must be present before any spine operation:

| Tool | Install Method | Verify |
|------|---------------|--------|
| git | Xcode CLT / brew | `git --version` |
| jq | brew | `jq --version` |
| gh | brew | `gh --version` |
| yq | brew | `yq --version` |
| ripgrep | brew | `rg --version` |

### Phase 2: Shell & Git Configuration

| Item | Source | Target |
|------|--------|--------|
| gitconfig | `workbench/dotfiles/git/gitconfig.template` | `~/.gitconfig` |
| gitignore | `workbench/dotfiles/git/gitignore_global` | `~/.gitignore_global` |
| shell aliases | `workbench/dotfiles/zsh/legacy-aliases.sh` | sourced in `~/.zshrc` |
| compat shim | `workbench/dotfiles/zsh/*-compat.sh` | sourced in `~/.zshrc` |

### Phase 3: Managed Config Symlinks

Handled by `host.macbook.managed_configs.apply`:

| Target | Source |
|--------|--------|
| `~/.hammerspoon` | `workbench/dotfiles/hammerspoon/.hammerspoon` |
| `~/.raycast-scripts` | `workbench/dotfiles/raycast` |
| `~/.codex/config.toml` | `workbench/dotfiles/codex/config.toml` |
| `~/.config/opencode/opencode.json` | `workbench/dotfiles/opencode/opencode.json` |

### Phase 4: Productivity Tools (Optional)

| Tool | Type | Install |
|------|------|---------|
| SuperWhisper | cask | `brew install --cask superwhisper` |
| Espanso | formula | `brew install espanso` |
| Maccy | cask | `brew install --cask maccy` |

### Phase 5: Claude Entrypoint Surfaces

| Surface | Source | Deployed To |
|---------|--------|-------------|
| Claude Code shim | `agentic-spine/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| OpenCode instructions | `workbench/dotfiles/opencode/OPENCODE.md` | `~/.config/opencode/OPENCODE.md` |
| Codex instructions | `workbench/dotfiles/codex/AGENTS.md` | `~/.codex/AGENTS.md` (if applicable) |

## Execution Model

```
Operator invokes:
  ./bin/ops cap run host.macbook.bootstrap [--phase N] [--dry-run|--execute]

Capability:
  1. Checks prerequisites (Homebrew installed)
  2. Runs phases 1-5 in order (or single phase if --phase specified)
  3. Each phase is idempotent (skips already-satisfied items)
  4. Produces receipt with per-item pass/skip/fail status
  5. Calls host.macbook.managed_configs.apply for phase 3+5
  6. Final drift check via host.macbook.drift.check
```

## Drift Enforcement

`host.macbook.drift.check` verifies bootstrap state is maintained:
- CLI tools from Phase 1 are present
- Symlinks from Phase 3 point to correct targets
- Claude entrypoints from Phase 5 are valid

## What This Contract Does NOT Cover

- Homebrew installation itself (prerequisite, not managed by spine)
- macOS system settings (display, keyboard, trackpad)
- App Store applications
- IDE plugins or extensions
- Hardware-specific configuration
