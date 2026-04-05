#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
AGENT="$ROOT/ops/plugins/providers/bin/infisical-agent.sh"
D213="$ROOT/surfaces/verify/d213-secrets-registered-route-lock.sh"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

fixture_root() {
  local dir="$1"
  mkdir -p "$dir/ops/bindings" "$dir/home"

  cat > "$dir/ops/bindings/secrets.inventory.yaml" <<'YAML'
projects:
  - name: infrastructure
    id: fixture-infrastructure
    project_health: active
YAML

  cat > "$dir/ops/bindings/secrets.enforcement.contract.yaml" <<'YAML'
version: 1
mode: strict
enforcement:
  root_path_allowed: false
  unknown_infrastructure_keys_allowed: false
  inferred_routes_allowed: false
  ambiguous_routes_allowed: false
  deprecated_alias_writes_allowed: false
break_glass:
  enabled: true
  env_var: CUSTOM_BREAK_GLASS
  required_value: "1"
  reason_required_env_var: CUSTOM_BREAK_GLASS_REASON
YAML

  cat > "$dir/ops/bindings/secrets.namespace.policy.yaml" <<'YAML'
rules:
  required_key_paths:
    REGISTERED_KEY: /spine/services/demo
    ROOT_KEY: /
  key_path_overrides: {}
  planned_key_paths: {}
YAML
}

run_expect_fail() {
  local label="$1"
  shift
  local output rc
  set +e
  output="$("$@" 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    pass "$label exits non-zero"
  else
    fail "$label exits non-zero"
  fi
  printf '%s' "$output"
}

echo "secrets route enforcement tests"
echo "════════════════════════════════════════"

command -v yq >/dev/null 2>&1 || {
  echo "FAIL: missing dependency yq" >&2
  exit 1
}
command -v rg >/dev/null 2>&1 || {
  echo "FAIL: missing dependency rg" >&2
  exit 1
}

if [[ -x "$AGENT" ]]; then
  pass "canonical infisical agent is executable"
else
  fail "canonical infisical agent is executable"
fi

if d213_out="$(bash "$D213" 2>&1)"; then
  pass "D213 surface passes"
else
  fail "D213 surface passes"
  echo "$d213_out" >&2
fi

d213_mode="$(yq e -r '.gates[] | select(.id == "D213") | .mode' "$REGISTRY")"
d213_warn="$(yq e -r '.gates[] | select(.id == "D213") | (.warn_only // false | tostring)' "$REGISTRY")"
if [[ "$d213_mode" == "enforce" && "$d213_warn" == "false" ]]; then
  pass "D213 posture is enforce/false"
else
  fail "D213 posture is enforce/false"
fi

d225_mode="$(yq e -r '.gates[] | select(.id == "D225") | .mode' "$REGISTRY")"
d225_warn="$(yq e -r '.gates[] | select(.id == "D225") | (.warn_only // false | tostring)' "$REGISTRY")"
d225_posture="$(yq e -r '.gates[] | select(.id == "D225") | .enforcement_decision.posture // ""' "$REGISTRY")"
d225_as_of="$(yq e -r '.gates[] | select(.id == "D225") | .enforcement_decision.as_of // ""' "$REGISTRY")"
if [[ "$d225_mode" == "report" && "$d225_warn" == "true" && "$d225_posture" == "hold_report_only" && "$d225_as_of" == "2026-04-05" ]]; then
  pass "D225 hold posture is explicit and dated"
else
  fail "D225 hold posture is explicit and dated"
fi

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
fixture_root "$fixture"

unknown_out="$(run_expect_fail "unknown infrastructure/prod route" env HOME="$fixture/home" SPINE_ROOT="$fixture" SPINE_REPO="$fixture" INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=dummy "$AGENT" get infrastructure prod MISSING_KEY)"
if echo "$unknown_out" | rg -q 'unregistered key route'; then
  pass "unknown infrastructure/prod route is blocked"
else
  fail "unknown infrastructure/prod route is blocked"
fi
if echo "$unknown_out" | rg -q 'unbound variable|invalid indirect expansion'; then
  fail "custom break-glass indirection stays safe under nounset"
else
  pass "custom break-glass indirection stays safe under nounset"
fi

root_out="$(run_expect_fail "root path guard" env HOME="$fixture/home" SPINE_ROOT="$fixture" SPINE_REPO="$fixture" bash -lc "source \"$AGENT\" && resolved=\$(resolve_secret_path infrastructure prod ROOT_KEY) && guard_registered_secret_path infrastructure prod ROOT_KEY \"\$resolved\"")"
if echo "$root_out" | rg -q "root path '/' is blocked"; then
  pass "root path fallback is blocked"
else
  fail "root path fallback is blocked"
fi

auth_out="$(run_expect_fail "unset auth secret" env HOME="$fixture/home" SPINE_ROOT="$fixture" SPINE_REPO="$fixture" INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET= "$AGENT" auth-token)"
if echo "$auth_out" | rg -q 'INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET not set'; then
  pass "missing critical auth input fails closed"
else
  fail "missing critical auth input fails closed"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
