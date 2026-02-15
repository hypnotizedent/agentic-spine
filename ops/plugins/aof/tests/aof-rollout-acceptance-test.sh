#!/usr/bin/env bash
# aof-rollout-acceptance-test — Live bridge acceptance for AOF consumer surface.
#
# Requires: running bridge on 127.0.0.1:8799 with both tokens loaded.
# Env: MAILROOM_BRIDGE_TOKEN (operator), MAILROOM_BRIDGE_MONITOR_TOKEN (monitor)
#
# GAP-OP-461: T1–T5  Live smoke (5/5 aof.* caps via /cap/run)
# GAP-OP-459: T6–T10 Monitor RBAC proof (200 for 2, 403 for 3)
# GAP-OP-460: T11–T15 Receipt chain (receipt path exists on disk)
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BRIDGE="http://127.0.0.1:8799"
OPERATOR_TOKEN="${MAILROOM_BRIDGE_TOKEN:-}"
MONITOR_TOKEN="${MAILROOM_BRIDGE_MONITOR_TOKEN:-}"

# Try loading from state files if env not set
if [[ -z "$OPERATOR_TOKEN" && -f "$SP/mailroom/state/mailroom-bridge.token" ]]; then
  OPERATOR_TOKEN="$(tr -d '\r\n' < "$SP/mailroom/state/mailroom-bridge.token")"
fi
if [[ -z "$MONITOR_TOKEN" && -f "$SP/mailroom/state/mailroom-bridge-monitor.token" ]]; then
  MONITOR_TOKEN="$(tr -d '\r\n' < "$SP/mailroom/state/mailroom-bridge-monitor.token")"
fi

if [[ -z "$OPERATOR_TOKEN" ]]; then
  echo "FATAL: no operator token available" >&2
  exit 1
fi
if [[ -z "$MONITOR_TOKEN" ]]; then
  echo "FATAL: no monitor token available" >&2
  exit 1
fi

PASS=0
FAIL=0
RECEIPT_PATHS=()

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

# Use python3 for JSON parsing to handle control characters in cap output
json_field() {
  python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
val = data.get('$1', '')
print(val if val is not None else '')
"
}

json_output_valid() {
  # Validate that .output parses as JSON and has required envelope keys
  python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
output = data.get('output', '')
try:
    env = json.loads(output)
    assert 'capability' in env and 'schema_version' in env and 'data' in env
    sys.exit(0)
except Exception:
    sys.exit(1)
"
}

cap_run_raw() {
  local token="$1"
  local cap="$2"
  shift 2
  local args_json="[]"
  if [[ $# -gt 0 ]]; then
    args_json="[$(printf '"%s"' "$1")]"
  fi
  curl -s \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"capability\": \"$cap\", \"args\": $args_json}" \
    -o /tmp/aof-acceptance-body.json \
    -w "%{http_code}" \
    "$BRIDGE/cap/run"
}

echo "AOF Rollout Acceptance Test"
echo "════════════════════════════════════════"
echo "Bridge: $BRIDGE"
echo ""

# ════════════════════════════════════════
# GAP-OP-461: Live smoke test (T1–T5)
# ════════════════════════════════════════
echo "── GAP-OP-461: Live /cap/run smoke test ──"

AOF_CAPS="aof.status aof.version aof.policy.show aof.tenant.show aof.verify"

for cap in $AOF_CAPS; do
  echo ""
  echo "T: $cap via operator /cap/run --json"
  http_code="$(cap_run_raw "$OPERATOR_TOKEN" "$cap" "--json")"

  if [[ "$http_code" != "200" ]]; then
    fail "$cap returned HTTP $http_code (expected 200)"
    continue
  fi

  # Bridge response envelope
  bridge_status="$(cat /tmp/aof-acceptance-body.json | json_field status)"
  if [[ "$bridge_status" != "done" ]]; then
    fail "$cap bridge status=$bridge_status (expected done)"
    continue
  fi

  # The output field contains the cap's JSON envelope
  if ! cat /tmp/aof-acceptance-body.json | json_output_valid; then
    fail "$cap output not valid JSON envelope"
    continue
  fi

  # Save receipt for T11-T15
  receipt="$(cat /tmp/aof-acceptance-body.json | json_field receipt)"
  RECEIPT_PATHS+=("$cap:$receipt")

  pass "$cap: HTTP 200, status=done, valid JSON envelope"
done

# ════════════════════════════════════════
# GAP-OP-459: Monitor RBAC proof (T6–T10)
# ════════════════════════════════════════
echo ""
echo "── GAP-OP-459: Monitor RBAC proof ──"

# Monitor should get 200 for these
MONITOR_ALLOW="aof.status aof.version"
for cap in $MONITOR_ALLOW; do
  echo ""
  echo "T: monitor token → $cap (expect 200)"
  http_code="$(cap_run_raw "$MONITOR_TOKEN" "$cap" "--json")"

  if [[ "$http_code" == "200" ]]; then
    pass "monitor → $cap: HTTP 200 (allowed)"
  else
    fail "monitor → $cap: HTTP $http_code (expected 200)"
  fi
done

# Monitor should get 403 for these
MONITOR_DENY="aof.policy.show aof.tenant.show aof.verify"
for cap in $MONITOR_DENY; do
  echo ""
  echo "T: monitor token → $cap (expect 403)"
  http_code="$(cap_run_raw "$MONITOR_TOKEN" "$cap")"

  if [[ "$http_code" == "403" ]]; then
    pass "monitor → $cap: HTTP 403 (denied)"
  else
    fail "monitor → $cap: HTTP $http_code (expected 403)"
  fi
done

# ════════════════════════════════════════
# GAP-OP-460: Receipt chain validation (T11–T15)
# ════════════════════════════════════════
echo ""
echo "── GAP-OP-460: Receipt chain validation ──"

for entry in "${RECEIPT_PATHS[@]}"; do
  cap="${entry%%:*}"
  receipt_path="${entry#*:}"
  echo ""
  echo "T: $cap receipt exists on disk"

  if [[ -z "$receipt_path" ]]; then
    fail "$cap: no receipt path in bridge response"
    continue
  fi

  # Receipt path may be absolute or relative to spine root
  if [[ "$receipt_path" == /* ]]; then
    full_path="$receipt_path"
  else
    full_path="$SP/$receipt_path"
  fi

  if [[ -f "$full_path" ]]; then
    # Verify receipt has minimum required content (Run ID or Capability field)
    if grep -qE "Run ID|Capability" "$full_path" 2>/dev/null; then
      pass "$cap: receipt exists + has Run ID"
    else
      fail "$cap: receipt exists but missing Run ID"
    fi
  else
    fail "$cap: receipt not found at $full_path"
  fi
done

echo ""
echo "════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
echo ""
echo "Summary:"
echo "  GAP-OP-461 (smoke):   T1–T5"
echo "  GAP-OP-459 (RBAC):    T6–T10"
echo "  GAP-OP-460 (receipt): T11–T15"
exit "$FAIL"
