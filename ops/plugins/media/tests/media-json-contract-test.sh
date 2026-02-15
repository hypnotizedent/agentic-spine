#!/usr/bin/env bash
# media-json-contract-test — Offline JSON envelope contract for media read-only caps.
#
# These tests intentionally use a non-existent VM filter to avoid hitting real
# infrastructure while still validating the JSON shape and stable keys.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }

assert_envelope() {
  local cap="$1"
  local out="$2"

  if ! echo "$out" | jq -e . >/dev/null 2>&1; then
    return 1
  fi

  echo "$out" | jq -e \
    --arg cap "$cap" '
      type == "object" and
      .capability == $cap and
      (.schema_version | type == "string" and length > 0) and
      (.generated_at | type == "string" and length > 0) and
      (.status | type == "string" and length > 0) and
      (.data | type == "object")
    ' >/dev/null 2>&1
}

echo "media-json-contract Tests"
echo "════════════════════════════════════════"

echo ""
echo "T1: media.health.check --json emits valid envelope (offline filter)"
(
  out="$(bash "$SP/ops/plugins/media/bin/media-health-check" --json --vm __none__)"
  assert_envelope "media.health.check" "$out"
  echo "$out" | jq -e '.data.vm_filter == "__none__"' >/dev/null
) && pass "media.health.check JSON envelope valid" || fail "media.health.check JSON envelope invalid"

echo ""
echo "T2: media.service.status --json emits valid envelope (offline filter)"
(
  out="$(bash "$SP/ops/plugins/media/bin/media-service-status" --json --vm __none__ --service __none__)"
  assert_envelope "media.service.status" "$out"
  echo "$out" | jq -e '.data.vm_filter == "__none__" and .data.service_filter == "__none__"' >/dev/null
) && pass "media.service.status JSON envelope valid" || fail "media.service.status JSON envelope invalid"

echo ""
echo "T3: media.nfs.verify --json emits valid envelope (offline filter)"
(
  out="$(bash "$SP/ops/plugins/media/bin/media-nfs-verify" --json --vm __none__)"
  assert_envelope "media.nfs.verify" "$out"
  echo "$out" | jq -e '.data.vm_filter == "__none__"' >/dev/null
) && pass "media.nfs.verify JSON envelope valid" || fail "media.nfs.verify JSON envelope invalid"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"

