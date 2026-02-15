#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PREFLIGHT="$ROOT/ops/commands/preflight.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

require_text() {
  local haystack="$1"
  local text="$2"
  local label="$3"
  if echo "$haystack" | grep -Fq -- "$text"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "preflight gate-domain banner tests"
echo "════════════════════════════════════════"

if [[ -x "$PREFLIGHT" ]]; then
  pass "preflight executable present"
else
  fail "preflight executable present"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

# T1: default preflight includes gate domain section and command hints
set +e
preflight_out="$(OPS_PREFLIGHT_ALLOW_DEGRADED=1 "$PREFLIGHT" 2>&1)"
preflight_rc=$?
set -e
if [[ "$preflight_rc" -eq 0 ]]; then
  pass "preflight exits 0 with degraded override"
else
  fail "preflight exits 0 with degraded override (rc=$preflight_rc)"
fi
require_text "$preflight_out" "Gate Domains:" "preflight prints Gate Domains section"
require_text "$preflight_out" "verify.drift_gates.certify --list-domains" "preflight prints list-domains hint"
require_text "$preflight_out" "verify.drift_gates.certify --domain <name> --brief" "preflight prints domain brief hint"
require_text "$preflight_out" "selected: core (default(core))" "default selected domain is core"

# T2: OPS_GATE_DOMAIN=aof renders selected domain and inline brief
set +e
aof_out="$(OPS_PREFLIGHT_ALLOW_DEGRADED=1 OPS_GATE_DOMAIN=aof "$PREFLIGHT" 2>&1)"
aof_rc=$?
set -e
if [[ "$aof_rc" -eq 0 ]]; then
  pass "preflight exits 0 for OPS_GATE_DOMAIN=aof"
else
  fail "preflight exits 0 for OPS_GATE_DOMAIN=aof (rc=$aof_rc)"
fi
require_text "$aof_out" "selected: aof (OPS_GATE_DOMAIN)" "preflight reports selected aof domain"
require_text "$aof_out" 'Domain: `aof`' "preflight embeds aof domain brief"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
