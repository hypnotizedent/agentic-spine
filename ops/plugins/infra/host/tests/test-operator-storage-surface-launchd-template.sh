#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
TEMPLATE="$ROOT/ops/plugins/infra/host/launchd/com.ronny.operator-storage-surface-sync.plist"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

echo "operator storage surface launchd template tests"
echo "════════════════════════════════════════"

template_text="$(cat "$TEMPLATE")"

echo ""
echo "── T1: launchd template carries governed override for mutating sync capability ──"
assert_contains "$template_text" "<key>OPS_GOVERNED_MAIN_OVERRIDE</key>" "template declares governed override key"
assert_contains "$template_text" "<string>1</string>" "template enables governed override"

echo ""
echo "── T2: launchd template still invokes the installed stable spine-ops shim ──"
assert_contains "$template_text" "/Users/ronnyworks/.local/bin/spine-ops" "template keeps stable shim program path"
assert_contains "$template_text" "operator.storage.surface.sync" "template still targets storage sync capability"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
