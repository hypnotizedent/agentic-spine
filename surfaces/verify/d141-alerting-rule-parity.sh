#!/usr/bin/env bash
# TRIAGE: Ensure every stability.control.contract critical domain has exactly one alerting rule entry in alerting.rules.yaml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/stability.control.contract.yaml"
RULES="$ROOT/ops/bindings/alerting.rules.yaml"

source "$ROOT/ops/lib/resolve-policy.sh"
resolve_policy_knobs >/dev/null 2>&1 || true

fail() {
  echo "D141 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing stability contract: $CONTRACT"
[[ -f "$RULES" ]] || fail "missing alerting rules: $RULES"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"

missing=0
duplicate=0

while IFS= read -r domain; do
  [[ -z "$domain" || "$domain" == "null" ]] && continue
  count="$(yq -r ".rules | map(select(.domain_id == \"$domain\")) | length" "$RULES")"
  if [[ "$count" == "0" ]]; then
    echo "  missing alert rule for domain: $domain" >&2
    missing=$((missing + 1))
  elif [[ "$count" != "1" ]]; then
    echo "  duplicate alert rules for domain: $domain (count=$count)" >&2
    duplicate=$((duplicate + 1))
  fi
done < <(yq -r '.critical_domains[].id' "$CONTRACT")

if [[ "$missing" -gt 0 || "$duplicate" -gt 0 ]]; then
  fail "alerting rule parity errors found (missing=$missing duplicate=$duplicate)"
fi

domain_count="$(yq -r '.critical_domains | length' "$CONTRACT")"
rule_count="$(yq -r '.rules | length' "$RULES")"

echo "D141 PASS: alerting rule parity valid (critical_domains=$domain_count rules=$rule_count)"
