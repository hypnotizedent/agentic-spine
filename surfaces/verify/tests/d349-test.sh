#!/usr/bin/env bash
# Tests for D349: prompt lineage receipt lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d349-prompt-lineage-receipt-lock.sh"

PASS=0
FAIL_COUNT=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1" >&2; }

echo "--- Test 1: live state PASS ---"
if SPINE_ROOT="$SP" bash "$GATE" >/dev/null 2>&1; then
  pass "D349 passes on current repo state"
else
  fail "D349 should pass on current repo state"
fi

echo "--- Test 2: missing prompt registry FAIL ---"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/surfaces/verify" "$TMP/ops/bindings" "$TMP/ops/plugins/evidence/bin" "$TMP/ops/plugins"
cp "$GATE" "$TMP/surfaces/verify/d349-prompt-lineage-receipt-lock.sh"
chmod +x "$TMP/surfaces/verify/d349-prompt-lineage-receipt-lock.sh"

cat > "$TMP/ops/capabilities.yaml" <<'EOF'
capabilities:
  prompt.registry.status: {}
EOF
cat > "$TMP/ops/bindings/capability_map.yaml" <<'EOF'
capabilities:
  prompt.registry.status: {}
EOF
cat > "$TMP/ops/bindings/routing.dispatch.yaml" <<'EOF'
capabilities:
  prompt.registry.status: {}
EOF
cat > "$TMP/ops/plugins/MANIFEST.yaml" <<'EOF'
plugins:
  - name: evidence
    scripts:
      - bin/prompt-registry-status
    capabilities:
      - prompt.registry.status
EOF
cat > "$TMP/ops/bindings/orchestration.exec_receipt.schema.json" <<'EOF'
{"type":"object","properties":{}}
EOF
cat > "$TMP/ops/plugins/evidence/bin/receipts-exec-emit" <<'EOF'
#!/usr/bin/env bash
echo "{}" > "${@: -1}"
EOF
cat > "$TMP/ops/plugins/evidence/bin/prompt-registry-status" <<'EOF'
#!/usr/bin/env bash
echo '{"summary":{"status":"ok"},"prompt_lineage":{"prompt_set_id":"x","version":"x","source_hash":"none"}}'
EOF
chmod +x "$TMP/ops/plugins/evidence/bin/receipts-exec-emit" "$TMP/ops/plugins/evidence/bin/prompt-registry-status"

output="$(SPINE_ROOT="$TMP" bash "$TMP/surfaces/verify/d349-prompt-lineage-receipt-lock.sh" 2>&1)" && rc=$? || rc=$?
if [[ "$rc" -ne 0 ]]; then
  pass "D349 correctly fails when prompt registry is missing (rc=$rc)"
else
  fail "D349 should fail when prompt registry is missing (rc=$rc, output: $output)"
fi

echo
echo "Results: $PASS passed, $FAIL_COUNT failed"
exit "$FAIL_COUNT"
