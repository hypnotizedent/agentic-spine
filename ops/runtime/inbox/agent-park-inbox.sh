#!/usr/bin/env bash
set -euo pipefail

# agent-park-inbox.sh - Move inbox files to parked backup
#
# Usage: agent-park-inbox.sh [KEEP_REGEX]
#
# Arguments:
#   KEEP_REGEX  Optional regex of filenames to keep (not park)
#
# Examples:
#   agent-park-inbox.sh                  # Park all inbox files
#   agent-park-inbox.sh "^S2026"         # Keep files starting with S2026
#
# Parked files go to: mailroom/state/backups/inbox-parked/<timestamp>/

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '3,14p' "$0" | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

# SPINE paths (canonical)
SPINE="${SPINE_REPO:-$HOME/Code/agentic-spine}"
INBOX="${SPINE_INBOX:-$SPINE/mailroom/inbox}"
PARK_BASE="${SPINE_STATE:-$SPINE/mailroom/state}/backups/inbox-parked"
TS="$(date +%Y%m%d-%H%M%S)"
PARK_DIR="$PARK_BASE/$TS"

mkdir -p "$PARK_DIR"

KEEP_REGEX="${1:-^$}"  # regex of filenames to keep (optional)

shopt -s nullglob
moved=0
for f in "$INBOX"/*.md; do
  base="$(basename "$f")"
  if [[ "$base" =~ $KEEP_REGEX ]]; then
    continue
  fi
  mv -v "$f" "$PARK_DIR/"
  moved=$((moved+1))
done

echo "Parked $moved file(s) to: $PARK_DIR"
echo "Inbox now:"
ls -la "$INBOX"
