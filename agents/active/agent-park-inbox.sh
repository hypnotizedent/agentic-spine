#!/usr/bin/env bash
set -euo pipefail

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
