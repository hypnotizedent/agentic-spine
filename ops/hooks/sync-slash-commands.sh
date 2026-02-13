#!/usr/bin/env bash
# sync-slash-commands.sh — Sync repo-governed slash commands to execution surfaces.
#
# Source: surfaces/commands/*.md (canonical, version-controlled)
# Target: ~/.claude/commands/*.md (Claude Code execution surface)
#
# Usage:
#   ops/hooks/sync-slash-commands.sh [--dry-run]
#
set -euo pipefail

SPINE="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SOURCE_DIR="$SPINE/surfaces/commands"
CLAUDE_TARGET="$HOME/.claude/commands"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

# Ensure target directory exists
if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$CLAUDE_TARGET"
fi

synced=0
skipped=0

for src in "$SOURCE_DIR"/*.md; do
  [[ -f "$src" ]] || continue
  fname="$(basename "$src")"
  dst="$CLAUDE_TARGET/$fname"

  # Check if target differs from source
  if [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1; then
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "WOULD SYNC: $fname"
  else
    cp "$src" "$dst"
    echo "SYNCED: $fname"
  fi
  synced=$((synced + 1))
done

echo ""
echo "Done: $synced synced, $skipped unchanged"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry run — no files changed)"
fi
