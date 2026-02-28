#!/usr/bin/env bash
# TRIAGE: fail if critical tier has no outcome probes declared.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/outcome.slo.contract.yaml"
SCRIPT="$ROOT/ops/plugins/verify/bin/outcome-slo-report"
CAPS="$ROOT/ops/capabilities.yaml"
MAP="$ROOT/ops/bindings/capability_map.yaml"
DISPATCH="$ROOT/ops/bindings/routing.dispatch.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"

fail() {
  echo "D290 FAIL: $*" >&2
  exit 1
}

for f in "$CONTRACT" "$SCRIPT" "$CAPS" "$MAP" "$DISPATCH" "$MANIFEST"; do
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
  yq e -r ".capabilities.\"$cap\".command // \"\"" "$CAPS" | grep -q . || fail "probe capability not registered in capabilities.yaml: $cap"
done

rg -n '^\s*outcome\.slo\.report:' "$CAPS" >/dev/null 2>&1 || fail "capabilities.yaml missing outcome.slo.report"
rg -n '^\s*outcome\.slo\.report:' "$MAP" >/dev/null 2>&1 || fail "capability_map.yaml missing outcome.slo.report"
rg -n '^\s*outcome\.slo\.report:' "$DISPATCH" >/dev/null 2>&1 || fail "routing.dispatch.yaml missing outcome.slo.report"
rg -n 'outcome\.slo\.report' "$MANIFEST" >/dev/null 2>&1 || fail "plugin manifest missing outcome.slo.report"

echo "D290 PASS: outcome SLO presence lock enforced"
