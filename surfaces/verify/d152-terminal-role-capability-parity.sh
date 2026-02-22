#!/usr/bin/env bash
# TRIAGE: Ensures every capability listed in terminal.role.contract.yaml roles exists in ops/capabilities.yaml.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/terminal.role.contract.yaml"
CAPS="$ROOT/ops/capabilities.yaml"

fail() {
  echo "D152 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing terminal.role.contract.yaml"
[[ -f "$CAPS" ]] || fail "missing capabilities.yaml"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"

role_caps="$(yq e '.roles[].capabilities[]' "$CONTRACT" 2>/dev/null | sort -u)"
[[ -n "$role_caps" ]] || fail "no capabilities found in contract roles"

missing=()
while IFS= read -r cap; do
  [[ -n "$cap" ]] || continue
  exists="$(yq e ".capabilities | has(\"$cap\")" "$CAPS" 2>/dev/null)"
  if [[ "$exists" != "true" ]]; then
    missing+=("$cap")
  fi
done <<< "$role_caps"

if [[ "${#missing[@]}" -gt 0 ]]; then
  fail "terminal role capabilities not found in capabilities.yaml: ${missing[*]}"
fi

total="$(echo "$role_caps" | wc -l | tr -d ' ')"
echo "D152 PASS: all $total terminal role capabilities exist in capabilities.yaml"
exit 0
