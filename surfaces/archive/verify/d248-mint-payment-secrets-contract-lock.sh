#!/usr/bin/env bash
# TRIAGE: Keep payment secret aliases and namespace routes aligned across canonical contracts.
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
      echo "Usage: d248-mint-payment-secrets-contract-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D248 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

fail() { echo "D248 FAIL: $*" >&2; exit 1; }
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

payment_ns="$(yq -r '.modules.payment.namespace // ""' "$CONTRACT")"
[[ -n "$payment_ns" && "$payment_ns" != "null" ]] || finding "payment namespace missing in W45 contract"

policy_ns="$(yq -r '.rules.module_namespaces.payment // ""' "$NAMESPACE_POLICY")"
[[ "$policy_ns" == "$payment_ns" ]] || finding "module_namespaces.payment mismatch: contract='$payment_ns' policy='$policy_ns'"

mapfile -t payment_keys < <(yq -r '.modules.payment.aliases | to_entries[].value' "$CONTRACT" 2>/dev/null || true)
(( ${#payment_keys[@]} > 0 )) || finding "payment aliases empty in W45 contract"

for key in "${payment_keys[@]}"; do
  [[ -n "$key" && "$key" != "null" ]] || continue

  policy_path="$(yq -r ".rules.key_path_overrides.${key} // \"\"" "$NAMESPACE_POLICY")"
  [[ "$policy_path" == "$payment_ns" ]] || finding "namespace policy route mismatch for $key: expected '$payment_ns' got '$policy_path'"

  runway_project="$(yq -r ".key_overrides.${key}.project // \"\"" "$RUNWAY_CONTRACT")"
  runway_path="$(yq -r ".key_overrides.${key}.path // \"\"" "$RUNWAY_CONTRACT")"
  [[ "$runway_project" == "infrastructure" ]] || finding "runway key_overrides.$key project must be infrastructure (got '$runway_project')"
  [[ "$runway_path" == "$payment_ns" ]] || finding "runway key_overrides.$key path mismatch: expected '$payment_ns' got '$runway_path'"
done

if (( FINDINGS > 0 )); then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D248 FAIL: payment secrets contract findings=$FINDINGS"
    exit 1
  fi
  echo "D248 REPORT: payment secrets contract findings=$FINDINGS"
  exit 0
fi

echo "D248 PASS: payment secret routes and aliases are contract-aligned"
