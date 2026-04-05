#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
D62="$ROOT/surfaces/verify/d62-git-remote-parity-lock.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

require_regex() {
  local haystack="$1"
  local pattern="$2"
  local label="$3"
  if echo "$haystack" | grep -Eq "$pattern"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "D62 publication surface tests"
echo "════════════════════════════════════════"

command -v yq >/dev/null 2>&1 || {
  echo "FAIL: missing dependency yq" >&2
  exit 1
}

if [[ -x "$D62" ]]; then
  pass "D62 surface is executable"
else
  fail "D62 surface is executable"
fi

d62_scope="$(yq e -r '.gates[] | select(.id == "D62") | .reporting_scope // ""' "$REGISTRY")"
d62_posture="$(yq e -r '.gates[] | select(.id == "D62") | .advisory_decision.posture // ""' "$REGISTRY")"
d62_action="$(yq e -r '.gates[] | select(.id == "D62") | .advisory_decision.operator_action // ""' "$REGISTRY")"

if [[ "$d62_scope" == "publication_only" ]]; then
  pass "D62 registry scope is publication-only"
else
  fail "D62 registry scope is publication-only"
fi

if [[ "$d62_posture" == "publication_only_advisory" ]]; then
  pass "D62 registry posture is publication-only advisory"
else
  fail "D62 registry posture is publication-only advisory"
fi

if echo "$d62_action" | grep -Eq 'explicit publication review|publication/admin mirror maintenance'; then
  pass "D62 operator action is publication-specific"
else
  fail "D62 operator action is publication-specific"
fi

if d62_out="$(bash "$D62" 2>&1)"; then
  pass "D62 surface exits 0 when origin authority is healthy"
else
  fail "D62 surface exits 0 when origin authority is healthy"
  echo "$d62_out" >&2
fi

require_regex "$d62_out" '^PASS: D62 canonical origin authority confirmed' "D62 confirms canonical origin authority"

if ! echo "$d62_out" | grep -Eq '^WARN:'; then
  pass "D62 no longer emits operational WARN lines"
else
  fail "D62 no longer emits operational WARN lines"
fi

require_regex "$d62_out" '^PUBLICATION(:| ADVISORY:)' "D62 emits publication status"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
