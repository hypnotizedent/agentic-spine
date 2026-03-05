#!/usr/bin/env bash
# TRIAGE: Forbidden legal/tax-advice language detected in case artifacts. Remove definitive advice, advisory language, and legal conclusions from .md/.yaml outputs. Scripts may only be flagged for echo/printf output strings.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

HITS=0
err() {
  echo "  FAIL: $*" >&2
  HITS=$((HITS + 1))
}

CASE_BASE="$ROOT/mailroom/state/cases/tax-legal"
BIN_DIR="$ROOT/ops/plugins/taxlegal/bin"

# If no case directories exist, nothing to scan
if [[ ! -d "$CASE_BASE" ]]; then
  echo "D359 PASS: taxlegal-boundary-lock (no case directories exist)"
  exit 0
fi

# Forbidden patterns (case-insensitive)
FORBIDDEN_PATTERNS=(
  "you should"
  "you must"
  "this is legal"
  "this is illegal"
  "this is deductible"
  "you owe"
  "file this way"
  "I recommend"
  "we recommend"
)

# ── Check 1: Scan .md and .yaml files in case drafts/ and research/ directories ──
SCANNED=0
while IFS= read -r -d '' file; do
  SCANNED=$((SCANNED + 1))
  for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if grep -inP "$pattern" "$file" >/dev/null 2>&1; then
      while IFS= read -r match_line; do
        err "$(basename "$file"):$match_line — forbidden pattern: '$pattern'"
      done < <(grep -inP "$pattern" "$file" 2>/dev/null)
    fi
  done
done < <(find "$CASE_BASE" -type f \( -name '*.md' -o -name '*.yaml' \) \( -path '*/drafts/*' -o -path '*/research/*' \) -print0 2>/dev/null)

# ── Check 2: Scan echo/printf output strings in bin/ scripts ──
if [[ -d "$BIN_DIR" ]]; then
  while IFS= read -r -d '' script; do
    SCANNED=$((SCANNED + 1))
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
      # Only match patterns inside echo/printf string arguments
      if grep -inP '^\s*(echo|printf)\s+.*'"$pattern" "$script" >/dev/null 2>&1; then
        while IFS= read -r match_line; do
          err "$(basename "$script"):$match_line — forbidden pattern in output string: '$pattern'"
        done < <(grep -inP '^\s*(echo|printf)\s+.*'"$pattern" "$script" 2>/dev/null)
      fi
    done
  done < <(find "$BIN_DIR" -type f -print0 2>/dev/null)
fi

# If no files were found to scan, still PASS
if [[ "$SCANNED" -eq 0 ]]; then
  echo "D359 PASS: taxlegal-boundary-lock (no case artifact files found to scan)"
  exit 0
fi

# ── Result ──
if [[ "$HITS" -gt 0 ]]; then
  echo "D359 FAIL: $HITS violation(s)"
  exit 1
fi

echo "D359 PASS: taxlegal-boundary-lock ($SCANNED files scanned, 0 forbidden patterns)"
exit 0
