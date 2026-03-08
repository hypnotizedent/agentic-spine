#!/usr/bin/env bash
# TRIAGE: Enforce Mint UI placement boundaries per MINT_UI_HOME_MODEL_V1
# D382: mint-ui-placement-lock
# Prevents React/SPA drift in module public/ directories and cross-module customer UX in backend modules.
# Authority: docs/governance/MINT_UI_HOME_MODEL_V1.md
# Delegates to mint-modules guard script (canonical enforcement logic).
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MINT_MODULES_ROOT="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
UI_PLACEMENT_GUARD="$MINT_MODULES_ROOT/scripts/guard/ui-placement-lock.sh"

fail() {
  echo "D382 FAIL: $*" >&2
  exit 1
}

# Verify mint-modules checkout exists
[[ -d "$MINT_MODULES_ROOT" ]] || fail "mint-modules not found at $MINT_MODULES_ROOT (set MINT_MODULES_ROOT)"

# Verify guard script exists
[[ -f "$UI_PLACEMENT_GUARD" ]] || fail "UI placement guard missing: $UI_PLACEMENT_GUARD"
[[ -x "$UI_PLACEMENT_GUARD" ]] || fail "UI placement guard not executable: $UI_PLACEMENT_GUARD"

# Verify we're in a git repository with staged files to check
if ! git -C "$MINT_MODULES_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  fail "mint-modules is not a git repository"
fi

# Run the canonical UI placement guard in "all" mode (full-repo scan for verify)
# The guard script supports --mode staged (pre-commit) and --mode all (verify)
cd "$MINT_MODULES_ROOT" || fail "cannot cd to mint-modules"

# Capture both stdout and stderr, preserve exit code
output=$("$UI_PLACEMENT_GUARD" --mode all 2>&1) || gate_exit=$?
gate_exit=${gate_exit:-0}

# If guard failed, show its output and fail
if [[ $gate_exit -ne 0 ]]; then
  echo "$output"
  fail "UI placement lock violations detected (see output above)"
fi

# Success
echo "D382 PASS: mint UI placement boundaries enforced (no React in module public/, no cross-module drift)"
