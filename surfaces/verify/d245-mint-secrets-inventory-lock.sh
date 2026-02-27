#!/usr/bin/env bash
# TRIAGE: Ensure W45 mint secrets promotion inventory contract exists and remains structurally complete.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/mint.secrets.promotion.contract.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d245-mint-secrets-inventory-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D245 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

fail() { echo "D245 FAIL: $*" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: ops/bindings/mint.secrets.promotion.contract.yaml"
yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: ops/bindings/mint.secrets.promotion.contract.yaml"

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$CONTRACT" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || fail "invalid policy mode '$MODE'"

FINDINGS=0
finding() {
  echo "  HIGH: $*"
  FINDINGS=$((FINDINGS + 1))
}

for module in shipping payment notifications; do
  ns="$(yq -r ".modules.${module}.namespace // \"\"" "$CONTRACT")"
  [[ -n "$ns" && "$ns" != "null" ]] || finding "missing namespace for module '$module'"

  cfg="$(yq -r ".modules.${module}.runtime_config // \"\"" "$CONTRACT")"
  if [[ -z "$cfg" || "$cfg" == "null" ]]; then
    finding "missing runtime_config for module '$module'"
  elif [[ ! -f "$cfg" ]]; then
    finding "runtime_config path not found for module '$module': $cfg"
  fi

  env_count="$(yq -r ".modules.${module}.runtime_env_keys | length" "$CONTRACT" 2>/dev/null || echo 0)"
  [[ "$env_count" =~ ^[0-9]+$ ]] || env_count=0
  (( env_count > 0 )) || finding "runtime_env_keys missing/empty for module '$module'"

  alias_count="$(yq -r ".modules.${module}.aliases | keys | length" "$CONTRACT" 2>/dev/null || echo 0)"
  [[ "$alias_count" =~ ^[0-9]+$ ]] || alias_count=0
  (( alias_count > 0 )) || finding "aliases missing/empty for module '$module'"
done

for source_key in namespace_policy runway_contract bundle_contract; do
  source_rel="$(yq -r ".source_contracts.${source_key} // \"\"" "$CONTRACT")"
  if [[ -z "$source_rel" || "$source_rel" == "null" ]]; then
    finding "source_contracts.${source_key} missing"
    continue
  fi
  [[ -f "$ROOT/$source_rel" ]] || finding "missing source contract file: $source_rel"
done

if (( FINDINGS > 0 )); then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D245 FAIL: mint secrets inventory findings=$FINDINGS"
    exit 1
  fi
  echo "D245 REPORT: mint secrets inventory findings=$FINDINGS"
  exit 0
fi

echo "D245 PASS: mint secrets inventory contract complete"
