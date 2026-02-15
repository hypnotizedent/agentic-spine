#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
CERTIFIER="$ROOT/ops/plugins/verify/bin/drift-gates-certify"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

require_match() {
  local haystack="$1"
  local pattern="$2"
  local label="$3"
  if echo "$haystack" | grep -q -- "$pattern"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "drift-gates-certify domain tests"
echo "════════════════════════════════════════"

if [[ -x "$CERTIFIER" ]]; then
  pass "certifier executable present"
else
  fail "certifier executable present"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

# T1: --list-domains returns expected configured packs
if list_out="$("$CERTIFIER" --list-domains 2>&1)"; then
  pass "--list-domains exits 0"
else
  fail "--list-domains exits 0"
  echo "$list_out" >&2
fi

for domain in core secrets aof home media rag workbench infra loop_gap; do
  if echo "$list_out" | grep -qx "$domain"; then
    pass "--list-domains includes $domain"
  else
    fail "--list-domains includes $domain"
  fi
done

# T2: --domain secrets --brief renders only secrets pack summary
if brief_out="$("$CERTIFIER" --domain secrets --brief 2>&1)"; then
  pass "--domain secrets --brief exits 0"
else
  fail "--domain secrets --brief exits 0"
  echo "$brief_out" >&2
fi
require_match "$brief_out" 'Domain: `secrets`' "brief output identifies secrets domain"
require_match "$brief_out" 'Gate IDs:' "brief output includes gate id line"
require_match "$brief_out" 'D112' "secrets brief includes D112"

# T3: unknown domain fails with valid-domain hint
set +e
bad_out="$("$CERTIFIER" --domain invalid-domain --brief 2>&1)"
bad_rc=$?
set -e
if [[ "$bad_rc" -eq 2 ]]; then
  pass "unknown domain exits 2"
else
  fail "unknown domain exits 2 (rc=$bad_rc)"
fi
require_match "$bad_out" '^ERROR: unknown domain:' "unknown domain error emitted"
require_match "$bad_out" '^VALID:' "unknown domain lists valid options"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
