#!/usr/bin/env bash
# TRIAGE: Use lowercase ~/code/ in workbench scripts. Remove legacy repo name references.
# D78: Workbench path lock
# Prevents uppercase code-dir and ronny-ops path drift in workbench executable surfaces.
# Checks forbidden case variants and legacy naming in active scripts.
# Allows: explicit lowercase /code/ required by D72/D74

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME}/code/workbench"
fi

fail() {
  echo "D78 FAIL: $*" >&2
  exit 1
}

[[ -d "$WORKBENCH_ROOT" ]] || fail "workbench not found: $WORKBENCH_ROOT"

command -v rg >/dev/null 2>&1 || fail "rg (ripgrep) required"

VIOLATIONS=()

# Build forbidden uppercase pattern dynamically (avoids D42 false positive on this file)
_UPPER_CODE="/$(printf '%s' 'Code')/"
_UPPER_ABS="/Users/ronnyworks${_UPPER_CODE}"

# Scan surfaces: scripts + raycast + dotfiles (excluding .archive, .git, docs)
SCAN_DIRS=()
for d in scripts dotfiles; do
  [[ -d "$WORKBENCH_ROOT/$d" ]] && SCAN_DIRS+=("$WORKBENCH_ROOT/$d")
done

if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
  echo "D78 PASS: workbench path lock (no scan dirs found)"
  exit 0
fi

# ── Check 1: Uppercase code-dir in executable surfaces ──
UPPERCASE_HITS="$(rg -l "$_UPPER_ABS" "${SCAN_DIRS[@]}" \
  --glob '*.sh' --glob '*.lua' --glob '*.json' \
  --glob '!**/.archive/**' --glob '!**/archive/**' \
  --glob '!**/.git/**' 2>/dev/null || true)"

if [[ -n "$UPPERCASE_HITS" ]]; then
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    rel="${hit#$WORKBENCH_ROOT/}"
    VIOLATIONS+=("uppercase code-dir path: $rel")
  done <<< "$UPPERCASE_HITS"
fi

# ── Check 2: home-variable uppercase code-dir patterns ──
HOME_CODE_HITS="$(rg -l "(\\\$HOME|~)${_UPPER_CODE}" "${SCAN_DIRS[@]}" \
  --glob '*.sh' --glob '*.lua' \
  --glob '!**/.archive/**' --glob '!**/archive/**' \
  --glob '!**/.git/**' 2>/dev/null || true)"

if [[ -n "$HOME_CODE_HITS" ]]; then
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    rel="${hit#$WORKBENCH_ROOT/}"
    # Exclude lines that are comments
    non_comment="$(rg "(\\\$HOME|~)${_UPPER_CODE}" "$hit" | grep -v '^\s*#' | grep -v '^\s*--' || true)"
    if [[ -n "$non_comment" ]]; then
      VIOLATIONS+=("\$HOME or ~ uppercase code-dir pattern: $rel")
    fi
  done <<< "$HOME_CODE_HITS"
fi

# ── Check 3: ronny-ops path drift ──
# Exclude governance/detection scripts that legitimately reference the term
# (authority-trace, ci-runner-drift-check, install compat shims)
RONNY_OPS_EXCLUDE_PATTERN='authority-trace\.sh|ci-runner-drift-check\.sh|install\.sh|ronny-ops-compat\.sh|legacy-freeze\.sh|legacy-thaw\.sh'

RONNY_OPS_HITS="$(rg -l 'ronny-ops' "${SCAN_DIRS[@]}" \
  --glob '*.sh' --glob '*.lua' --glob '*.json' \
  --glob '!**/.archive/**' --glob '!**/archive/**' \
  --glob '!**/.git/**' 2>/dev/null || true)"

if [[ -n "$RONNY_OPS_HITS" ]]; then
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    rel="${hit#$WORKBENCH_ROOT/}"
    # Skip governance/detection scripts that legitimately reference the term
    if echo "$rel" | grep -Eq "$RONNY_OPS_EXCLUDE_PATTERN"; then
      continue
    fi
    # Exclude comment-only references
    non_comment="$(rg 'ronny-ops' "$hit" | grep -v '^\s*#' | grep -v '^\s*--' || true)"
    if [[ -n "$non_comment" ]]; then
      VIOLATIONS+=("ronny-ops reference in active surface: $rel")
    fi
  done <<< "$RONNY_OPS_HITS"
fi

# ── Report ──
if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  fail "$(printf '%s\n' "${VIOLATIONS[@]}")"
fi

echo "D78 PASS: workbench path lock enforced"
