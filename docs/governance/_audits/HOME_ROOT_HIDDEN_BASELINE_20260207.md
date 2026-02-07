---
status: baseline-snapshot
captured: 2026-02-07
scope: /Users/ronnyworks (hidden entries, depth=1)
loop_id: LOOP-HOST-CANONICALIZATION-20260207
---

# Home Root Hidden Baseline — 2026-02-07

## Classification Summary

| Category | Count | Action |
|----------|-------|--------|
| Managed | 29 | In `managed_hidden_roots` allowlist |
| Volatile | 10 | Tolerated, non-failing |
| Excluded | 2 | Skipped (`.Trash`, `Library`) |
| Forbidden | 5 | Stale backups + secret-bearing dirs |
| Unmanaged | 18 | Require classification decision |

## Managed (allowed-if-present)

```
.antigravity
.archive
.bun
.cache
.claude
.claude-server-commander
.claude-worktrees
.codex
.config/agentic-spine
.config/espanso
.config/infisical
.config/opencode
.copilot
.cursor
.docker
.gitconfig
.hammerspoon
.local
.npm
.npm-global
.ollama
.pyenv
.raycast-scripts
.skills
.ssh
.vscode
.zprofile
.zsh_sessions
.zshrc
```

## Volatile (tolerated, non-failing)

```
.bashrc
.claude.json
.claude.json.backup
.claude.json.backup.*
.claude.json.tmp.*
.DS_Store
.lesshst
.psql_history
.python-version
.viminfo
```

## Excluded (skipped by scanner)

```
.Trash
Library
```

## Forbidden (must not exist — gate fails)

```
.config/ronny-ops/*          (contains env.sh with secrets)
.hammerspoon.backup-*
.hammerspoon.moved-*
.raycast-scripts.backup-*
.config/espanso.backup-*
.config/espanso.moved-*
```

## Unmanaged (on disk, not yet classified)

```
.android
.anydesk
.bash_history
.CFUserTextEncoding
.claude-server-commander-logs
.DDLocalBackups
.DDPreview
.gem
.gemini
.hyper_plugins
.hyper.js
.idlerc
.infisical
.mc
.minirc.dfl
.npmrc
.oracle_jre_usage
.profile
.putty
.redhat
.SoulseekQt
.zsh_history
.zshrc.backup-20251226
```

> **Decision:** Unmanaged entries will be added to either `managed_hidden_roots` or
> `volatile_hidden_patterns` based on their nature. Items that are ephemeral OS/tool
> artifacts go to volatile. Items with ongoing user data go to managed.

## Reclassification (applied in allowlist update)

### Move to managed
- `.infisical` — Infisical CLI state
- `.zsh_history` — shell history (persistent)

### Move to volatile
- `.android` — SDK cache (auto-created)
- `.anydesk` — remote desktop cache
- `.bash_history` — legacy shell history
- `.CFUserTextEncoding` — macOS encoding preference
- `.claude-server-commander-logs` — transient logs
- `.DDLocalBackups` — DiskDrill backups
- `.DDPreview` — DiskDrill preview
- `.gem` — Ruby gem cache
- `.gemini` — Google AI CLI cache
- `.hyper_plugins` — Hyper terminal plugins
- `.hyper.js` — Hyper terminal config
- `.idlerc` — Python IDLE config
- `.mc` — Midnight Commander config
- `.minirc.dfl` — minicom config
- `.npmrc` — npm config
- `.oracle_jre_usage` — JRE usage tracking
- `.profile` — POSIX shell profile
- `.putty` — PuTTY config
- `.redhat` — Red Hat tooling cache
- `.SoulseekQt` — Soulseek config
- `.zshrc.backup-20251226` — stale shell backup
