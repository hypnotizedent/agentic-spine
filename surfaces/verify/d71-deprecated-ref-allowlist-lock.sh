#!/usr/bin/env bash
set -euo pipefail

# D71: Deprecated Reference Allowlist Lock
# Purpose: Verify that active non-legacy scripts in workbench do not reference
#          deprecated Infisical project names unless explicitly allowlisted.
# Scope:   workbench/scripts/** (excluding docs/legacy)
# Config:  ops/bindings/deprecated-project-allowlist.yaml
#
# Output contract:
#   - Exit 0 on PASS.
#   - Exit 1 on FAIL.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALLOWLIST="$ROOT/ops/bindings/deprecated-project-allowlist.yaml"
WORKBENCH="${HOME}/code/workbench"

fail() { echo "D71 FAIL: $*" >&2; exit 1; }

# Preconditions
[[ -f "$ALLOWLIST" ]] || fail "allowlist file missing: $ALLOWLIST"
[[ -d "$WORKBENCH/scripts" ]] || fail "workbench scripts dir missing: $WORKBENCH/scripts"
command -v yq >/dev/null 2>&1 || fail "missing dep: yq"

# Read deprecated project names from allowlist
DEPRECATED_NAMES="$(yq -r '.deprecated_projects[]' "$ALLOWLIST" 2>/dev/null)"
[[ -n "$DEPRECATED_NAMES" ]] || fail "no deprecated projects defined in allowlist"

# Read allowlisted relative paths
ALLOWED_PATHS="$(yq -r '.allowlist[].path' "$ALLOWLIST" 2>/dev/null)"

violations=0

while IFS= read -r deprecated_name; do
  [[ -n "$deprecated_name" ]] || continue

  # Search workbench/scripts for references to this deprecated project name
  # Exclude .md files, docs/, legacy/ directories
  while IFS= read -r match_file; do
    [[ -n "$match_file" ]] || continue

    # Get relative path from workbench root
    rel_path="${match_file#${WORKBENCH}/}"

    # Check if this file is in the allowlist
    is_allowed=false
    while IFS= read -r allowed; do
      [[ -n "$allowed" ]] || continue
      if [[ "$rel_path" == "$allowed" ]]; then
        is_allowed=true
        break
      fi
    done <<< "$ALLOWED_PATHS"

    if ! $is_allowed; then
      echo "D71 VIOLATION: $rel_path references deprecated project '$deprecated_name'" >&2
      violations=$((violations + 1))
    fi
  done < <(grep -rl --include='*.sh' --include='*.yaml' --include='*.yml' \
    --exclude-dir=docs --exclude-dir=legacy --exclude-dir=.git \
    "$deprecated_name" "$WORKBENCH/scripts/" 2>/dev/null || true)

done <<< "$DEPRECATED_NAMES"

if [[ "$violations" -gt 0 ]]; then
  fail "$violations file(s) reference deprecated project names without allowlist entry"
fi

exit 0
