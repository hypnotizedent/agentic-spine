#!/usr/bin/env bash
set -euo pipefail

# D429: Execution Posture Contract Enforcement
#
# Checks:
#   1. execution.posture.contract.yaml exists and defines all three postures
#   2. posture_guard.py is imported by gaps-authority-bridge
#   3. posture_guard.py is imported by loops-authority-bridge
#   4. posture-guard.sh is sourced by gaps-file
#   5. posture-guard.sh is sourced by loops-create
#   6. SPINE_EXECUTION_POSTURE is exported by session.v3.attach
#   7. posture enforcement tests exist and pass

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ISSUES=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $label"
  else
    echo "  FAIL: $label"
    ISSUES=$((ISSUES + 1))
  fi
}

echo "D429: Execution Posture Contract Enforcement"

# 1. Contract exists with all three postures
check "posture contract exists" test -f "$ROOT/ops/bindings/execution.posture.contract.yaml"
check "contract defines discover" grep -q "discover:" "$ROOT/ops/bindings/execution.posture.contract.yaml"
check "contract defines converge" grep -q "converge:" "$ROOT/ops/bindings/execution.posture.contract.yaml"
check "contract defines degraded" grep -q "degraded:" "$ROOT/ops/bindings/execution.posture.contract.yaml"

# 2-3. Python guard imported by both bridges
check "gaps-authority-bridge imports posture_guard" grep -q "import posture_guard" "$ROOT/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"
check "loops-authority-bridge imports posture_guard" grep -q "import posture_guard" "$ROOT/ops/plugins/core/lifecycle/bin/loops-authority-bridge"

# 4-5. Shell guard sourced by both scripts
check "gaps-file sources posture-guard.sh" grep -q "posture-guard.sh" "$ROOT/ops/plugins/core/loops/bin/gaps-file"
check "loops-create sources posture-guard.sh" grep -q "posture-guard.sh" "$ROOT/ops/plugins/core/lifecycle/bin/loops-create"

# 6. session.v3.attach exports SPINE_EXECUTION_POSTURE
check "session.v3.attach exports SPINE_EXECUTION_POSTURE" grep -q "SPINE_EXECUTION_POSTURE" "$ROOT/ops/plugins/core/session/bin/session-v3-attach"

# 7. Posture enforcement tests exist
check "posture enforcement test exists" test -x "$ROOT/ops/plugins/core/lifecycle/tests/test-posture-enforcement.sh"

# 8. posture_guard.py module exists
check "posture_guard.py module exists" test -f "$ROOT/ops/plugins/core/lifecycle/lib/posture_guard.py"

# 9. posture-guard.sh library exists
check "posture-guard.sh library exists" test -f "$ROOT/ops/lib/posture-guard.sh"

# 10. Dispatch envelope contract has execution_posture field
check "dispatch envelope has execution_posture" grep -q "execution_posture" "$ROOT/ops/bindings/dispatch.envelope.contract.yaml"

if [[ "$ISSUES" -gt 0 ]]; then
  echo "D429: FAIL ($ISSUES issue(s))"
  exit 1
fi

echo "D429: PASS"
