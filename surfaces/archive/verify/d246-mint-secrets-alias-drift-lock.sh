#!/usr/bin/env bash
# TRIAGE: Detect runtime-env to canonical-key alias drift for shipping/payment/notifications.
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
      echo "Usage: d246-mint-secrets-alias-drift-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D246 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

fail() { echo "D246 FAIL: $*" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v rg >/dev/null 2>&1 || fail "required tool missing: rg"
[[ -f "$CONTRACT" ]] || fail "missing contract: ops/bindings/mint.secrets.promotion.contract.yaml"
yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: ops/bindings/mint.secrets.promotion.contract.yaml"

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$CONTRACT" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || fail "invalid policy mode '$MODE'"

mapfile -t GENERIC_KEYS < <(yq -r '.policy.generic_runtime_keys[]?' "$CONTRACT" 2>/dev/null || true)
declare -A IS_GENERIC=()
for key in "${GENERIC_KEYS[@]}"; do
  [[ -n "$key" && "$key" != "null" ]] && IS_GENERIC["$key"]=1
done

FINDINGS=0
finding() {
  echo "  HIGH: $*"
  FINDINGS=$((FINDINGS + 1))
}

for module in shipping payment notifications; do
  cfg="$(yq -r ".modules.${module}.runtime_config // \"\"" "$CONTRACT")"
  [[ -f "$cfg" ]] || { finding "runtime_config missing for module '$module': $cfg"; continue; }

  mapfile -t runtime_keys < <(rg -o 'process\.env\.[A-Z0-9_]+' "$cfg" | sed 's/.*process\.env\.//' | sort -u)
  mapfile -t declared_keys < <(yq -r ".modules.${module}.runtime_env_keys[]?" "$CONTRACT" 2>/dev/null || true)

  declare -A declared_set=()
  for key in "${declared_keys[@]}"; do
    declared_set["$key"]=1
  done

  for key in "${declared_keys[@]}"; do
    if ! printf '%s\n' "${runtime_keys[@]}" | rg -qx "$key"; then
      finding "${module}: declared runtime_env_key '$key' not present in runtime config"
      continue
    fi

    canonical="$(yq -r ".modules.${module}.aliases.${key} // \"\"" "$CONTRACT")"
    if [[ -z "$canonical" || "$canonical" == "null" ]]; then
      finding "${module}: runtime key '$key' missing alias mapping"
      continue
    fi

    if [[ -n "${IS_GENERIC[$canonical]:-}" ]]; then
      finding "${module}: alias '$key -> $canonical' points to generic key, not canonical module key"
    fi
  done
done

if (( FINDINGS > 0 )); then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D246 FAIL: alias drift findings=$FINDINGS"
    exit 1
  fi
  echo "D246 REPORT: alias drift findings=$FINDINGS"
  exit 0
fi

echo "D246 PASS: runtime env aliases map cleanly to canonical module keys"
