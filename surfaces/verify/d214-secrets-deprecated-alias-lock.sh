#!/usr/bin/env bash
# TRIAGE: deprecated secret aliases must stay banned from canonical runtime/docs surfaces.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/secrets.enforcement.contract.yaml"
BUNDLE_CONTRACT="$ROOT/ops/bindings/secrets.bundle.contract.yaml"
POLICY="$ROOT/ops/bindings/secrets.namespace.policy.yaml"

fail() { echo "D214 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v rg >/dev/null 2>&1 || fail "required tool missing: rg"

[[ -f "$CONTRACT" ]] || fail "missing contract: ops/bindings/secrets.enforcement.contract.yaml"
[[ -f "$BUNDLE_CONTRACT" ]] || fail "missing bundle contract: ops/bindings/secrets.bundle.contract.yaml"
[[ -f "$POLICY" ]] || fail "missing policy: ops/bindings/secrets.namespace.policy.yaml"

yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: ops/bindings/secrets.enforcement.contract.yaml"

mapfile -t aliases < <(yq e -r '.deprecated_aliases | keys | .[]' "$CONTRACT" 2>/dev/null || true)
(( ${#aliases[@]} > 0 )) || fail "deprecated_aliases list is empty"

files=(
  "$ROOT/docs/governance/SECRETS_POLICY.md"
  "$ROOT/docs/governance/INFRASTRUCTURE_MAP.md"
  "$ROOT/docs/product/AOF_V1_1_SURFACE_UNIFICATION.md"
  "$ROOT/ops/plugins/observability/bin/finance-ronny-action-queue"
  "$ROOT/ops/plugins/observability/bin/finance-stack-status"
)

for alias in "${aliases[@]}"; do
  [[ -n "$alias" && "$alias" != "null" ]] || continue

  if yq e -r ".rules.key_path_overrides.${alias} // \"\"" "$POLICY" | rg -q '.'; then
    fail "alias '$alias' appears in rules.key_path_overrides"
  fi

  if yq e -r '.bundles[].keys[].name' "$BUNDLE_CONTRACT" | rg -qx "$alias"; then
    fail "alias '$alias' appears in bundle contract keys"
  fi

  ALIAS="$alias" yq e -r '.rules.forbidden_root_keys[]?' "$POLICY" | rg -qx "$alias" || \
    fail "alias '$alias' must remain in rules.forbidden_root_keys"

  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    if rg -n --fixed-strings "$alias" "$file" >/dev/null 2>&1; then
      fail "alias '$alias' found in $file"
    fi
  done
done

echo "D214 PASS: deprecated alias lock enforced"
