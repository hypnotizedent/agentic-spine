#!/usr/bin/env bash
# media-data-readiness-verify-test — Static contract checks for media data boringness gate.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SCRIPT="$SP/ops/plugins/domains/media/bin/media-data-readiness-verify"
DISPATCH="$SP/ops/bindings/routing.dispatch.yaml"
CAPS="$SP/ops/capabilities.yaml"
CONTRACT="$SP/ops/bindings/media.data.lifecycle.execution.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }
command -v yq >/dev/null 2>&1 || { echo "MISSING_DEP: yq" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "MISSING_DEP: python3" >&2; exit 2; }

if python3 -m py_compile "$SCRIPT"; then
  pass "media-data-readiness-verify syntax"
else
  fail "media-data-readiness-verify syntax"
fi

if python3 "$SCRIPT" --json | jq -e '.capability == "media.data.readiness.verify"' >/dev/null; then
  pass "media.data.readiness.verify json contract"
else
  fail "media.data.readiness.verify json contract"
fi

if python3 "$SCRIPT" --json | jq -e '.global_automation_state == "blocked"' >/dev/null; then
  pass "global automation blocked by residue"
else
  fail "global automation blocked by residue"
fi

if python3 "$SCRIPT" --json | jq -e '.services.jellyfin.effective_state == "allowed"' >/dev/null; then
  pass "jellyfin remains allowed"
else
  fail "jellyfin remains allowed"
fi

if python3 "$SCRIPT" --json | jq -e '.services.radarr.effective_state == "blocked"' >/dev/null; then
  pass "radarr blocked"
else
  fail "radarr blocked"
fi

if rg -q '^  media\.data\.readiness\.verify:$' "$DISPATCH" && rg -q 'capability_id: media\.data\.readiness\.verify' "$DISPATCH"; then
  pass "dispatch entry present"
else
  fail "dispatch entry missing"
fi

if rg -q '^  media\.data\.readiness\.verify:$' "$CAPS"; then
  pass "capability entry present"
else
  fail "capability entry missing"
fi

if yq -e '.authority.verification_surface.capability == "media.data.readiness.verify"' "$CONTRACT" >/dev/null; then
  pass "contract references readiness capability"
else
  fail "contract references readiness capability"
fi

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
