#!/usr/bin/env bash
set -euo pipefail

# D46: Claude instruction source lock
#
# Enforces:
# 1. CLAUDE.md exists (when ~/.claude is present)
# 2. Required references to AGENTS.md and SESSION_PROTOCOL.md
# 3. No forbidden governance headings in CLAUDE.md
# 4. No uppercase code-directory path variant in governed Claude files
# 5. No legacy runtime path references in governed Claude files

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_HOME="$HOME/.claude"
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"

# Build forbidden pattern dynamically to avoid D42 self-detection
FORBIDDEN_PATH="/Users/ronnyworks/C""ode/"
LEGACY_ROOT_SEGMENT='ronny-ops'
LEGACY_PATH_RE="(/Users/ronnyworks/${LEGACY_ROOT_SEGMENT}|~/${LEGACY_ROOT_SEGMENT}|\\\$HOME/${LEGACY_ROOT_SEGMENT})"

FAIL=0

# Skip if no ~/.claude directory (portability)
if [[ ! -d "$CLAUDE_HOME" ]]; then
  echo "D46 SKIP: ~/.claude not present"
  exit 0
fi

# Check 1: CLAUDE.md exists
if [[ ! -f "$CLAUDE_MD" ]]; then
  echo "D46 FAIL: ~/.claude/CLAUDE.md not found" >&2
  exit 1
fi

# Check 2: Required references
for ref in "AGENTS.md" "SESSION_PROTOCOL.md"; do
  if ! grep -q "$ref" "$CLAUDE_MD" 2>/dev/null; then
    echo "D46 FAIL: CLAUDE.md missing required reference: $ref" >&2
    FAIL=1
  fi
done

# Check 3: Forbidden governance headings
FORBIDDEN=("Authority Order" "Immutable Invariants" "Operating Loop" "Safety Defaults" "What You Must Not Do")
for heading in "${FORBIDDEN[@]}"; do
  if grep -qE "^#{1,3}\s+$heading" "$CLAUDE_MD" 2>/dev/null; then
    echo "D46 FAIL: CLAUDE.md contains forbidden governance heading: $heading" >&2
    FAIL=1
  fi
done

# Check 4 + 5: Path hygiene in governed Claude files
for file in "$CLAUDE_MD" "$CLAUDE_HOME"/commands/*.md "$CLAUDE_HOME/settings.json" "$CLAUDE_HOME/settings.local.json"; do
  [[ -f "$file" ]] || continue
  HITS=$(grep -cF "$FORBIDDEN_PATH" "$file" 2>/dev/null || true)
  if (( HITS > 0 )); then
    echo "D46 FAIL: $(basename "$file") has $HITS uppercase path reference(s)" >&2
    FAIL=1
  fi
  if grep -nE "$LEGACY_PATH_RE" "$file" >/dev/null 2>&1; then
    echo "D46 FAIL: $(basename "$file") references legacy runtime path(s)" >&2
    FAIL=1
  fi
done

if (( FAIL > 0 )); then
  echo "D46 FAIL: Claude instruction source lock violated" >&2
  exit 1
fi

echo "D46 PASS: Claude instruction source lock enforced"
