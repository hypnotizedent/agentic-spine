#!/usr/bin/env bash
set -euo pipefail

# D400: Path Portability — Hardcoded Spine Root Lock
# Ensures all gate scripts and plugin scripts use BASH_SOURCE-relative path resolution
# or runtime-paths.sh library instead of hardcoding $HOME/code/agentic-spine.
#
# Policy: No script under surfaces/verify/ or ops/plugins/ should contain
# "$HOME/code/agentic-spine" unless it also uses the BASH_SOURCE pattern
# or sources ops/lib/runtime-paths.sh.
#
# Background: ~20 gate scripts still hardcode $HOME/code/agentic-spine despite
# runtime-paths.sh existing. Each worktree/CI attempt rediscovers this (Loop 2).
# GAP-OP-1496 fixed D343 specifically; this gate prevents systemic recurrence.

GATE_ID="D400"
GATE_NAME="path-portability-hardcoded-spine-root-lock"

# Resolve the checkout being verified.
#
# Explicit --root wins. Otherwise prefer the current git checkout so running
# this gate from a packet worktree verifies that lane, not an ambient root
# checkout leaked through SPINE_ROOT. Fall back to this script's checkout for
# direct invocations outside git.
ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ -n "${2:-}" ]] || { echo "D400 FAIL: --root requires a path" >&2; exit 2; }
      ROOT="$(cd "${2:-}" && pwd -P)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>]" >&2
      echo "Detects hardcoded \$HOME/code/agentic-spine in gate/plugin scripts." >&2
      exit 0
      ;;
    *)
      echo "D400 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ROOT" ]]; then
  ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fi

VERIFY_TARGET_DIRS=(
  "$ROOT/surfaces/verify"
  "$ROOT/ops/plugins"
)

# Exit codes
EXIT_PASS=0
EXIT_FAIL=1

# Patterns to check
HARDCODED_PATTERN='$HOME/code/agentic-spine'
GOOD_PATTERN_1='BASH_SOURCE'
GOOD_PATTERN_2='runtime-paths.sh'

echo "═══════════════════════════════════════════════════════════════"
echo "GATE: $GATE_ID - $GATE_NAME"
echo "═══════════════════════════════════════════════════════════════"
echo "Policy: No hardcoded \$HOME/code/agentic-spine in gate/plugin scripts"
echo "Allowed: BASH_SOURCE-relative resolution or runtime-paths.sh sourcing"
echo ""

VIOLATIONS_FOUND=0
VIOLATIONS_FILE=$(mktemp)

for TARGET_DIR in "${VERIFY_TARGET_DIRS[@]}"; do
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "⚠️  Warning: $TARGET_DIR not found, skipping"
    continue
  fi

  echo "Checking: $TARGET_DIR"

  # Find all shell scripts
  while IFS= read -r -d '' script_file; do
    # Check if file contains hardcoded pattern
    if grep -q '\$HOME/code/agentic-spine' "$script_file" 2>/dev/null; then
      # Check if it also contains acceptable mitigation (BASH_SOURCE or runtime-paths.sh)
      if ! grep -q 'BASH_SOURCE' "$script_file" 2>/dev/null && \
         ! grep -q 'runtime-paths.sh' "$script_file" 2>/dev/null; then
        # Violation found
        VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
        RELATIVE_PATH="${script_file#$ROOT/}"
        echo "  ❌ VIOLATION: $RELATIVE_PATH"
        echo "$RELATIVE_PATH" >> "$VIOLATIONS_FILE"
      fi
    fi
  done < <(find "$TARGET_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0)
done

echo ""

if [[ $VIOLATIONS_FOUND -eq 0 ]]; then
  echo "✅ PASS: No hardcoded \$HOME/code/agentic-spine violations found"
  echo ""
  echo "All gate/plugin scripts use portable path resolution."
  rm -f "$VIOLATIONS_FILE"
  exit $EXIT_PASS
else
  echo "❌ FAIL: $VIOLATIONS_FOUND script(s) with hardcoded \$HOME/code/agentic-spine"
  echo ""
  echo "Violations:"
  cat "$VIOLATIONS_FILE"
  echo ""
  echo "Fix: Update scripts to use one of:"
  echo "  1. BASH_SOURCE-relative: ROOT=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")/../..\" && pwd)\""
  echo "  2. runtime-paths.sh: source ops/lib/runtime-paths.sh and use \$SPINE_ROOT"
  echo ""
  echo "Why this matters: Hardcoded paths break in worktrees, CI, and non-standard layouts."
  echo "runtime-paths.sh provides canonical resolution with SPINE_ROOT override support."
  rm -f "$VIOLATIONS_FILE"
  exit $EXIT_FAIL
fi
