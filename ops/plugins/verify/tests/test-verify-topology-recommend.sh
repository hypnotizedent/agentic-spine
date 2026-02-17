#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RUNNER="$ROOT/ops/plugins/verify/bin/verify-topology"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

require_json_array_contains() {
  local json="$1"
  local needle="$2"
  local label="$3"
  if echo "$json" | jq -e --arg needle "$needle" '.recommended_domains | index($needle) != null' >/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "verify-topology recommend tests"
echo "════════════════════════════════════════"

if [[ -x "$RUNNER" ]]; then
  pass "verify-topology executable present"
else
  fail "verify-topology executable present"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

if nohit_json="$($RUNNER recommend --json 2>&1)"; then
  pass "recommend --json exits 0"
else
  fail "recommend --json exits 0"
  echo "$nohit_json" >&2
fi
require_json_array_contains "$nohit_json" "core" "no-hit fallback includes core"

if proposal_path_json="$($RUNNER recommend --json --path ops/plugins/proposals/bin/proposals-apply 2>&1)"; then
  pass "recommend by proposal path exits 0"
else
  fail "recommend by proposal path exits 0"
  echo "$proposal_path_json" >&2
fi
require_json_array_contains "$proposal_path_json" "loop_gap" "proposal path routes to loop_gap"

if proposal_cap_json="$($RUNNER recommend --json --capability proposals.apply 2>&1)"; then
  pass "recommend by proposals.apply capability exits 0"
else
  fail "recommend by proposals.apply capability exits 0"
  echo "$proposal_cap_json" >&2
fi
require_json_array_contains "$proposal_cap_json" "loop_gap" "proposals.apply capability routes to loop_gap"

if nohit_text="$($RUNNER recommend 2>&1)"; then
  pass "recommend text mode exits 0"
else
  fail "recommend text mode exits 0"
  echo "$nohit_text" >&2
fi
if echo "$nohit_text" | grep -q 'verify.domain.run core'; then
  pass "text mode prints core fallback command"
else
  fail "text mode prints core fallback command"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
