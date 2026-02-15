#!/usr/bin/env bash
# TRIAGE: All secret-consuming scripts must use canonical infisical-agent.sh. Pattern B (CLI) and Pattern C (inline auth) are banned outside allowlist.
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
FAILURES=0

# Construct search patterns dynamically to avoid self-matching
PATTERN_B="$(printf '%s %s %s' 'infisical' 'secrets' 'get')"
PATTERN_C="$(printf '%s/%s' 'universal-auth' 'login')"
PATTERN_PATH="$(printf '%s/%s/%s' 'workbench/scripts' 'agents' 'infisical-agent')"

# D112 self-path (excluded from all scans)
SELF_PATH="surfaces/verify/d112-secrets-access-pattern-lock.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Pattern B: infisical CLI (infisical secrets get)
# Must not appear in any plugin/verify script
# ─────────────────────────────────────────────────────────────────────────────

pattern_b_hits=0
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  case "$file" in *.md|*.yaml|*.yml|*.json|*.txt) continue ;; esac
  local_rel="${file#$SPINE_ROOT/}"
  [[ "$local_rel" == "$SELF_PATH" ]] && continue
  if grep -qn "$PATTERN_B" "$file" 2>/dev/null; then
    if grep -n "$PATTERN_B" "$file" 2>/dev/null | grep -v '^[0-9]*:\s*#' | grep -q .; then
      echo "FAIL: Pattern B (CLI) found in: $file"
      pattern_b_hits=$((pattern_b_hits + 1))
    fi
  fi
done < <(find "$SPINE_ROOT/ops/plugins" -type f 2>/dev/null; find "$SPINE_ROOT/surfaces/verify" -type f 2>/dev/null)

if [[ "$pattern_b_hits" -gt 0 ]]; then
  FAILURES=$((FAILURES + pattern_b_hits))
fi

# ─────────────────────────────────────────────────────────────────────────────
# Pattern C: inline auth (curl to universal-auth/login)
# Allowed only in canonical source + D20 gate
# ─────────────────────────────────────────────────────────────────────────────

ALLOWLIST_PATTERN_C=(
  "ops/tools/infisical-agent.sh"
  "surfaces/verify/d20-secrets-drift.sh"
)

is_allowed() {
  local file="$1"
  local rel="${file#$SPINE_ROOT/}"
  [[ "$rel" == "$SELF_PATH" ]] && return 0
  for allowed in "${ALLOWLIST_PATTERN_C[@]}"; do
    [[ "$rel" == "$allowed" ]] && return 0
  done
  return 1
}

pattern_c_hits=0
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  case "$file" in *.md|*.yaml|*.yml|*.json|*.txt) continue ;; esac
  if is_allowed "$file"; then
    continue
  fi
  if grep -qn "$PATTERN_C" "$file" 2>/dev/null; then
    if grep -n "$PATTERN_C" "$file" 2>/dev/null | grep -v '^[0-9]*:\s*#' | grep -q .; then
      echo "FAIL: Pattern C (inline auth) found in: $file"
      pattern_c_hits=$((pattern_c_hits + 1))
    fi
  fi
done < <(find "$SPINE_ROOT/ops/plugins" -type f 2>/dev/null; find "$SPINE_ROOT/surfaces/verify" -type f 2>/dev/null; find "$SPINE_ROOT/ops/tools" -type f 2>/dev/null)

if [[ "$pattern_c_hits" -gt 0 ]]; then
  FAILURES=$((FAILURES + pattern_c_hits))
fi

# ─────────────────────────────────────────────────────────────────────────────
# Path normalization: INFISICAL_AGENT must not point to workbench shim
# ─────────────────────────────────────────────────────────────────────────────

path_hits=0
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  case "$file" in *.md|*.yaml|*.yml|*.json|*.txt) continue ;; esac
  local_rel="${file#$SPINE_ROOT/}"
  [[ "$local_rel" == "$SELF_PATH" ]] && continue
  if grep -qn "$PATTERN_PATH" "$file" 2>/dev/null; then
    if grep -n "$PATTERN_PATH" "$file" 2>/dev/null | grep -v '^[0-9]*:\s*#' | grep -q .; then
      echo "FAIL: workbench shim path in: $file"
      path_hits=$((path_hits + 1))
    fi
  fi
done < <(find "$SPINE_ROOT/ops/plugins" -type f 2>/dev/null; find "$SPINE_ROOT/surfaces/verify" -type f 2>/dev/null)

if [[ "$path_hits" -gt 0 ]]; then
  FAILURES=$((FAILURES + path_hits))
fi

# ─────────────────────────────────────────────────────────────────────────────
# RESULT
# ─────────────────────────────────────────────────────────────────────────────

if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: $FAILURES secrets access pattern violation(s)"
  exit 1
fi

echo "PASS: all secrets access via canonical infisical-agent.sh"
exit 0
