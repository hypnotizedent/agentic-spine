#!/usr/bin/env bash
# TRIAGE: Run ops/hooks/sync-agent-surfaces.sh after editing AGENT_GOVERNANCE_BRIEF.md.
# D65: Agent briefing sync lock
#
# Ensures AGENTS.md and CLAUDE.md contain the canonical governance brief
# from docs/governance/AGENT_GOVERNANCE_BRIEF.md between marker comments.
#
# Fix: run ops/hooks/sync-agent-surfaces.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

BRIEF_FILE="docs/governance/AGENT_GOVERNANCE_BRIEF.md"

# 1. Brief file must exist and be non-empty
[[ -f "$BRIEF_FILE" ]] || fail "D65: missing governance brief: $BRIEF_FILE"
[[ -s "$BRIEF_FILE" ]] || fail "D65: governance brief is empty: $BRIEF_FILE"

BRIEF=$(cat "$BRIEF_FILE")

# 2. Brief must have required sections
for section in "## Commit & Branch Rules" "## Capability Gotchas" "## Path & Reference Constraints" "## Verify & Receipts" "## Quick Commands"; do
  grep -qF "$section" "$BRIEF_FILE" || fail "D65: governance brief missing section: $section"
done

# 3. Check each surface file has synced content
for file in AGENTS.md CLAUDE.md; do
  [[ -f "$file" ]] || fail "D65: missing surface file: $file"

  # Extract content between markers
  if ! grep -q '<!-- GOVERNANCE_BRIEF -->' "$file"; then
    fail "D65: $file missing <!-- GOVERNANCE_BRIEF --> marker"
  fi
  if ! grep -q '<!-- /GOVERNANCE_BRIEF -->' "$file"; then
    fail "D65: $file missing <!-- /GOVERNANCE_BRIEF --> marker"
  fi

  # Extract embedded brief (content between the two markers, excluding the markers)
  EMBEDDED=$(awk '
    /^<!-- GOVERNANCE_BRIEF -->$/ { capture=1; next }
    /^<!-- \/GOVERNANCE_BRIEF -->$/ { capture=0; next }
    capture { print }
  ' "$file")

  if [[ "$EMBEDDED" != "$BRIEF" ]]; then
    fail "D65: $file governance brief out of sync (run: ops/hooks/sync-agent-surfaces.sh)"
  fi
done

echo "PASS: D65 agent briefing sync lock"
