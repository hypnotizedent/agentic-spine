#!/usr/bin/env bash
# aof-verify — Run AOF product gates (D91-D97).
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"
SCHEMA_VERSION="1.1.0"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
JSON_MODE=0

if [[ "${1:-}" == "--json" ]]; then
  JSON_MODE=1
  shift
fi

if [[ "$#" -gt 0 ]]; then
  echo "Usage: aof-verify.sh [--json]" >&2
  exit 1
fi

if [[ "$JSON_MODE" -eq 0 ]]; then
  echo "═══════════════════════════════════════"
  echo "  AOF VERIFY (product gates)"
  echo "═══════════════════════════════════════"
  echo ""
fi

FAIL=0
PASS_COUNT=0
SKIP=0
declare -a FAILED_GATES=()

run_gate() {
  local script="$1"
  local gate_id="$2"
  local desc="$3"

  if [[ ! -f "$script" ]]; then
    if [[ "$JSON_MODE" -eq 0 ]]; then
      echo "SKIP $gate_id $desc (script not found)"
    fi
    SKIP=$((SKIP + 1))
    return
  fi

  if [[ "$JSON_MODE" -eq 0 ]]; then
    echo -n "$gate_id $desc... "
  fi
  local tmp rc
  tmp="$(mktemp)"
  set +e
  bash "$script" >"$tmp" 2>&1
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    if [[ "$JSON_MODE" -eq 0 ]]; then
      echo "PASS"
    fi
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    if [[ "$JSON_MODE" -eq 0 ]]; then
      echo "FAIL (rc=$rc)"
    fi
    FAIL=$((FAIL + 1))
    FAILED_GATES+=("$gate_id")
    if [[ "$JSON_MODE" -eq 0 ]]; then
      sed -n '1,20p' "$tmp" | sed 's/^/  /' || true
    fi
  fi
  rm -f "$tmp" 2>/dev/null || true
}

run_gate "$SP/surfaces/verify/d91-aof-product-foundation-lock.sh"    "D91" "product foundation lock"
run_gate "$SP/surfaces/verify/d92-ha-config-version-control.sh"      "D92" "HA config version control"
run_gate "$SP/surfaces/verify/d93-tenant-storage-boundary-lock.sh"   "D93" "tenant storage boundary"
run_gate "$SP/surfaces/verify/d94-policy-runtime-enforcement-lock.sh" "D94" "policy runtime enforcement"
run_gate "$SP/surfaces/verify/d95-version-compat-matrix-lock.sh"     "D95" "version compat matrix"
run_gate "$SP/surfaces/verify/d96-evidence-retention-policy-lock.sh" "D96" "evidence retention policy"
run_gate "$SP/surfaces/verify/d97-surface-readonly-contract-lock.sh" "D97" "surface readonly contract"

TOTAL=$((PASS_COUNT + FAIL + SKIP))

if [[ "$JSON_MODE" -eq 1 ]]; then
  failed_gates_json="$(printf '%s\n' "${FAILED_GATES[@]-}" | jq -R . | jq -s 'map(select(length > 0))')"
  status="ok"
  [[ "$FAIL" -gt 0 ]] && status="failed"

  jq -n \
    --arg capability "aof.verify" \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg generated_at "$GENERATED_AT" \
    --arg status "$status" \
    --argjson passed "$PASS_COUNT" \
    --argjson failed "$FAIL" \
    --argjson skipped "$SKIP" \
    --argjson total "$TOTAL" \
    --argjson failed_gates "$failed_gates_json" \
    '{
      capability: $capability,
      schema_version: $schema_version,
      generated_at: $generated_at,
      status: $status,
      data: {
        product_gate_range: "D91-D97",
        passed: $passed,
        failed: $failed,
        skipped: $skipped,
        total: $total,
        failed_gates: $failed_gates
      }
    }'
else
  echo ""
  echo "───────────────────────────────────────"
  echo "Results: $PASS_COUNT passed, $FAIL failed, $SKIP skipped"
  echo "═══════════════════════════════════════"
fi

exit "$FAIL"
