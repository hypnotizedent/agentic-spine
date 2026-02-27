#!/usr/bin/env bash
# TRIAGE: Keep notifications secret aliases and provider dependency routes aligned.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/mint.secrets.promotion.contract.yaml"
NAMESPACE_POLICY="$ROOT/ops/bindings/secrets.namespace.policy.yaml"
RUNWAY_CONTRACT="$ROOT/ops/bindings/secrets.runway.contract.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d249-mint-notifications-secrets-contract-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D249 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

fail() { echo "D249 FAIL: $*" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: ops/bindings/mint.secrets.promotion.contract.yaml"
[[ -f "$NAMESPACE_POLICY" ]] || fail "missing policy: ops/bindings/secrets.namespace.policy.yaml"
[[ -f "$RUNWAY_CONTRACT" ]] || fail "missing contract: ops/bindings/secrets.runway.contract.yaml"

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$CONTRACT" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || fail "invalid policy mode '$MODE'"

FINDINGS=0
finding() {
  echo "  HIGH: $*"
  FINDINGS=$((FINDINGS + 1))
}

notifications_ns="$(yq -r '.modules.notifications.namespace // ""' "$CONTRACT")"
[[ -n "$notifications_ns" && "$notifications_ns" != "null" ]] || finding "notifications namespace missing in W45 contract"

policy_ns="$(yq -r '.rules.module_namespaces.notifications // ""' "$NAMESPACE_POLICY")"
[[ "$policy_ns" == "$notifications_ns" ]] || finding "module_namespaces.notifications mismatch: contract='$notifications_ns' policy='$policy_ns'"

mapfile -t notifications_keys < <(yq -r '.modules.notifications.aliases | to_entries[].value' "$CONTRACT" 2>/dev/null || true)
(( ${#notifications_keys[@]} > 0 )) || finding "notifications aliases empty in W45 contract"

for key in "${notifications_keys[@]}"; do
  [[ -n "$key" && "$key" != "null" ]] || continue

  policy_path="$(yq -r ".rules.key_path_overrides.${key} // \"\"" "$NAMESPACE_POLICY")"
  [[ "$policy_path" == "$notifications_ns" ]] || finding "namespace policy route mismatch for $key: expected '$notifications_ns' got '$policy_path'"

  runway_project="$(yq -r ".key_overrides.${key}.project // \"\"" "$RUNWAY_CONTRACT")"
  runway_path="$(yq -r ".key_overrides.${key}.path // \"\"" "$RUNWAY_CONTRACT")"
  [[ "$runway_project" == "infrastructure" ]] || finding "runway key_overrides.$key project must be infrastructure (got '$runway_project')"
  [[ "$runway_path" == "$notifications_ns" ]] || finding "runway key_overrides.$key path mismatch: expected '$notifications_ns' got '$runway_path'"
done

provider_ns="$(yq -r '.shared_dependencies.notifications_provider_namespace // ""' "$CONTRACT")"
[[ -n "$provider_ns" && "$provider_ns" != "null" ]] || finding "shared_dependencies.notifications_provider_namespace missing"

mapfile -t provider_keys < <(yq -r '.shared_dependencies.notifications_provider_keys[]?' "$CONTRACT" 2>/dev/null || true)
for key in "${provider_keys[@]}"; do
  [[ -n "$key" && "$key" != "null" ]] || continue
  expected_path="$(yq -r ".shared_dependencies.notifications_provider_key_path_overrides.${key} // \"\"" "$CONTRACT")"
  if [[ -z "$expected_path" || "$expected_path" == "null" ]]; then
    expected_path="$provider_ns"
  fi
  policy_path="$(yq -r ".rules.key_path_overrides.${key} // \"\"" "$NAMESPACE_POLICY")"
  [[ "$policy_path" == "$expected_path" ]] || finding "provider key '$key' route mismatch: expected '$expected_path' got '$policy_path'"
done

if (( FINDINGS > 0 )); then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D249 FAIL: notifications secrets contract findings=$FINDINGS"
    exit 1
  fi
  echo "D249 REPORT: notifications secrets contract findings=$FINDINGS"
  exit 0
fi

echo "D249 PASS: notifications secret and provider routes are contract-aligned"
