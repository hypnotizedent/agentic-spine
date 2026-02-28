#!/usr/bin/env bash
# TRIAGE: wrong-domain verify routing must fail by contract.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"
VERIFY="$ROOT/ops/plugins/verify/bin/verify-topology"

fail() {
  echo "D282 FAIL: $*" >&2
  exit 1
}

[[ -f "$TOPOLOGY" ]] || fail "missing topology: $TOPOLOGY"
[[ -x "$VERIFY" ]] || fail "missing verify runner: $VERIFY"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

# W60 lock routing anchors must keep canonical domains.
check_domain() {
  local gid="$1"
  local expected="$2"
  local actual
  actual="$(yq e -r ".gate_assignments[] | select(.gate_id == \"$gid\") | .primary_domain // \"\"" "$TOPOLOGY")"
  [[ "$actual" == "$expected" ]] || err "$gid primary_domain mismatch (expected=$expected got=$actual)"
}

check_domain "D275" "core"
check_domain "D280" "observability"
check_domain "D284" "loop_gap"
check_domain "D288" "core"

# Route recommendation sanity: communications path must recommend communications.
rec_json="$($VERIFY recommend --path ops/plugins/communications/bin/communications-stack-status --json 2>/dev/null || true)"
if [[ -z "$rec_json" ]]; then
  err "verify-topology recommend returned empty output"
else
  if ! printf '%s' "$rec_json" | jq -e '.recommended_domains | index("communications") != null' >/dev/null 2>&1; then
    err "communications path did not recommend communications domain"
  fi
fi

# Observability path recommendation sanity.
obs_json="$($VERIFY recommend --path ops/bindings/services.health.yaml --json 2>/dev/null || true)"
if [[ -z "$obs_json" ]]; then
  err "verify-topology recommend returned empty output for services.health path"
else
  if ! printf '%s' "$obs_json" | jq -e '.recommended_domains | index("observability") != null' >/dev/null 2>&1; then
    err "services.health path did not recommend observability domain"
  fi
fi

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D282 PASS: verify routing correctness lock enforced"
