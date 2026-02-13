#!/usr/bin/env bash
# sync-slash-commands.sh — Sync repo-governed slash commands to agent surfaces.
#
# Source: surfaces/commands/*.md (canonical, version-controlled)
# Targets:
#   1. Claude Code:  ~/.claude/commands/
#   2. OpenCode:     ~/code/workbench/dotfiles/opencode/commands/
#   3. Codex:        AGENTS.md embed (governed skip — no slash-command files)
#
# Usage:
#   ops/hooks/sync-slash-commands.sh [--dry-run]
#
set -euo pipefail

SPINE="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SOURCE_DIR="$SPINE/surfaces/commands"

CLAUDE_TARGET="$HOME/.claude/commands"
OPENCODE_TARGET="$HOME/code/workbench/dotfiles/opencode/commands"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

# ── sync_target ─────────────────────────────────────────────────────────
# Syncs source commands to a single target directory.
# Args: $1 = label, $2 = target directory
# Sets: _synced, _unchanged (caller reads these after return)
# ────────────────────────────────────────────────────────────────────────
sync_target() {
  local label="$1"
  local target_dir="$2"

  _synced=0
  _unchanged=0

  echo "=== $label (target: $target_dir) ==="

  # Ensure target directory exists
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$target_dir"
  fi

  for src in "$SOURCE_DIR"/*.md; do
    [[ -f "$src" ]] || continue
    local fname
    fname="$(basename "$src")"
    local dst="$target_dir/$fname"

    # Check if target matches source already
    if [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      _unchanged=$((_unchanged + 1))
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "WOULD SYNC: $fname"
    else
      cp "$src" "$dst"
      echo "SYNCED: $fname"
    fi
    _synced=$((_synced + 1))
  done

  # Report target-only files that exist in destination but not in source (skip, don't delete)
  if [[ -d "$target_dir" ]]; then
    for dst_file in "$target_dir"/*.md; do
      [[ -f "$dst_file" ]] || continue
      local dst_fname
      dst_fname="$(basename "$dst_file")"
      if [[ ! -f "$SOURCE_DIR/$dst_fname" ]]; then
        echo "SKIP: $dst_fname (${label}-only, not in source)"
      fi
    done
  fi

  local total=$((_synced + _unchanged))
  echo "Done: $_synced synced, $_unchanged unchanged"
  echo ""
}

# ── Target 1: Claude Code ──────────────────────────────────────────────
sync_target "Claude Code" "$CLAUDE_TARGET"
claude_synced=$_synced
claude_total=$((_synced + _unchanged))

# ── Target 2: OpenCode ─────────────────────────────────────────────────
sync_target "OpenCode" "$OPENCODE_TARGET"
opencode_synced=$_synced
opencode_total=$((_synced + _unchanged))

# ── Target 3: Codex (governed skip) ────────────────────────────────────
echo "=== Codex (target: AGENTS.md embed) ==="
echo "SKIP: Codex uses AGENTS.md governance embed, not slash-command files."
echo ""

# ── Summary ─────────────────────────────────────────────────────────────
echo "Summary: claude=${claude_synced}/${claude_total}, opencode=${opencode_synced}/${opencode_total}, codex=skip"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry run — no files changed)"
fi
