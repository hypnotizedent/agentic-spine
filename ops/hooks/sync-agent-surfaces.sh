#!/usr/bin/env bash
set -euo pipefail

# sync-agent-surfaces.sh
# Reads docs/governance/AGENT_GOVERNANCE_BRIEF.md and replaces the content
# between <!-- GOVERNANCE_BRIEF --> markers in AGENTS.md and CLAUDE.md.
#
# Usage: bash ops/hooks/sync-agent-surfaces.sh
# Run after editing AGENT_GOVERNANCE_BRIEF.md.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BRIEF_FILE="docs/governance/AGENT_GOVERNANCE_BRIEF.md"

if [[ ! -f "$BRIEF_FILE" ]]; then
  echo "ERROR: missing $BRIEF_FILE" >&2
  exit 1
fi

[[ -s "$BRIEF_FILE" ]] || { echo "ERROR: $BRIEF_FILE is empty" >&2; exit 1; }

synced=0

for file in AGENTS.md CLAUDE.md; do
  if [[ ! -f "$file" ]]; then
    echo "WARN: $file not found, skipping" >&2
    continue
  fi

  if ! grep -q '<!-- GOVERNANCE_BRIEF -->' "$file"; then
    echo "WARN: $file has no <!-- GOVERNANCE_BRIEF --> marker, skipping" >&2
    continue
  fi

  # Build replacement: head (before open marker, inclusive) + brief + tail (from close marker, inclusive)
  {
    # Print everything up to and including the open marker
    sed -n '1,/^<!-- GOVERNANCE_BRIEF -->$/p' "$file"
    # Print the brief content
    cat "$BRIEF_FILE"
    # Print from the close marker onward
    sed -n '/^<!-- \/GOVERNANCE_BRIEF -->$/,$p' "$file"
  } > "${file}.tmp" && mv "${file}.tmp" "$file"

  echo "OK: synced $file"
  synced=$((synced + 1))
done

if [[ "$synced" -eq 0 ]]; then
  echo "ERROR: no files were synced" >&2
  exit 1
fi

echo "Done: $synced file(s) synced from $BRIEF_FILE"
