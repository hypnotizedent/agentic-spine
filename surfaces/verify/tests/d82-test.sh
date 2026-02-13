#!/usr/bin/env bash
# Tests for D82: share publish governance lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d82-share-publish-governance-lock.sh"
PASS=0; FAIL_COUNT=0
pass() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1" >&2; }

# Test 1: Gate passes on current repo state
echo "--- Test 1: live state PASS ---"
if bash "$GATE" >/dev/null 2>&1; then
  pass "D82 passes on current repo state"
else
  fail "D82 should pass on current repo state"
fi

# Test 2: Gate detects missing binding (negative test)
echo "--- Test 2: missing binding detection ---"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Copy just enough structure for the gate to find things
mkdir -p "$TMP/docs/governance" "$TMP/ops/bindings" "$TMP/ops/plugins/share/bin"
cp "$SP/docs/governance/WORKBENCH_SHARE_PROTOCOL.md" "$TMP/docs/governance/"
cp "$SP/ops/bindings/share.publish.allowlist.yaml" "$TMP/ops/bindings/"
# Deliberately omit denylist and remote to trigger failure
cp "$SP/ops/capabilities.yaml" "$TMP/ops/"
cp "$SP/ops/plugins/MANIFEST.yaml" "$TMP/ops/plugins/"
for s in share-publish-preflight share-publish-preview share-publish-apply; do
  cp "$SP/ops/plugins/share/bin/$s" "$TMP/ops/plugins/share/bin/"
done

output=$(SPINE_ROOT="$TMP" bash "$GATE" 2>&1) && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D82 correctly detects missing bindings (rc=$rc)"
else
  fail "D82 should have failed for missing bindings"
fi

# Test 3: Structural checks (gate executable + bindings exist)
echo "--- Test 3: structural checks ---"
if [[ -x "$GATE" \
  && -f "$SP/ops/bindings/share.publish.allowlist.yaml" \
  && -f "$SP/ops/bindings/share.publish.denylist.yaml" \
  && -f "$SP/ops/bindings/share.publish.remote.yaml" \
  && -f "$SP/docs/governance/WORKBENCH_SHARE_PROTOCOL.md" ]]; then
  pass "D82 gate executable and all share bindings exist"
else
  fail "D82 gate or share bindings missing"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
