#!/usr/bin/env bash
# D225: mint-live-before-auth-lock
# Enforce "live modules first" sequencing:
# - auth module remains deferred
# - live module baseline is green
# - queue explicitly blocks EQ-1 auth work by D225 until baseline passes
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/mint.module.sequence.contract.yaml"
STATUS_SURFACE="$ROOT/ops/plugins/mint/bin/mint-live-baseline-status"

fail() {
  echo "D225 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -x "$STATUS_SURFACE" ]] || fail "missing status surface: $STATUS_SURFACE"
command -v yq >/dev/null 2>&1 || fail "missing required dependency: yq"

auth_state="$(yq -r '.auth_module.state // ""' "$CONTRACT")"
blocked_gate="$(yq -r '.auth_module.blocked_by_gate // ""' "$CONTRACT")"
[[ "$auth_state" == "deferred" ]] || fail "auth_module.state must be deferred (actual=$auth_state)"
[[ "$blocked_gate" == "D225" ]] || fail "auth_module.blocked_by_gate must be D225 (actual=$blocked_gate)"

"$STATUS_SURFACE" --strict >/dev/null 2>&1 || fail "mint live baseline status is not green"

echo "D225 PASS: live modules baseline is green and auth remains properly deferred-by-gate"
