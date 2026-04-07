#!/usr/bin/env bash
# TRIAGE: fail if critical tier has no outcome probes declared.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/outcome.slo.contract.yaml"
SCRIPT="$ROOT/ops/plugins/core/verify/bin/outcome-slo-report"

fail() {
  echo "D290 FAIL: $*" >&2
  exit 1
}

for f in "$CONTRACT" "$SCRIPT"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

[[ -x "$SCRIPT" ]] || fail "script is not executable: $SCRIPT"

mapfile -t required_domains < <(yq e -r '.critical_tier.required_domains[]? // ""' "$CONTRACT" | sed '/^$/d')
[[ "${#required_domains[@]}" -gt 0 ]] || fail "critical_tier.required_domains is empty"

for domain in "${required_domains[@]}"; do
  count="$(yq e -r "[.probes[] | select((.tier // \"\") == \"critical\" and (.domain // \"\") == \"$domain\")] | length" "$CONTRACT")"
  [[ "$count" -gt 0 ]] || fail "missing critical-tier outcome probe for domain: $domain"
done

mapfile -t probe_caps < <(yq e -r '.probes[]?.capability // ""' "$CONTRACT" | sed '/^$/d' | sort -u)
for cap in "${probe_caps[@]}"; do
  [[ -n "$cap" ]] || fail "critical-tier outcome probe capability ref is empty"
done

echo "D290 PASS: outcome SLO presence lock enforced"
