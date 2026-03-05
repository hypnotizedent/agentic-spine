#!/usr/bin/env bash
# TRIAGE: Keep cc-benefits tracker schema/runtime/scheduler/capability wiring in deterministic parity.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/finance.cc-benefits.runtime.contract.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
MAP="$ROOT/ops/bindings/capability_map.yaml"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"

fail() {
  echo "D380 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -f "$CAPS" ]] || fail "missing capabilities registry"
[[ -f "$MAP" ]] || fail "missing capability map"
[[ -f "$REGISTRY" ]] || fail "missing launchd scheduler registry"

yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML contract: $CONTRACT"

plugin="$(yq e -r '.capabilities.plugin // ""' "$CONTRACT")"
[[ "$plugin" == "observability" ]] || fail "contract capabilities.plugin must be observability"

required_caps=()
while IFS= read -r cap; do
  [[ -n "$cap" ]] && required_caps+=("$cap")
done < <(yq e -r '.capabilities.required[]' "$CONTRACT")

for cap in "${required_caps[@]}"; do
  yq e -e ".capabilities.\"$cap\"" "$CAPS" >/dev/null 2>&1 || fail "missing capability in ops/capabilities.yaml: $cap"
  yq e -e ".capabilities.\"$cap\"" "$MAP" >/dev/null 2>&1 || fail "missing capability in capability_map.yaml: $cap"

  expected_script="$(yq e -r ".capabilities.script_map.\"$cap\" // \"\"" "$CONTRACT")"
  mapped_plugin="$(yq e -r ".capabilities.\"$cap\".plugin // \"\"" "$MAP")"
  mapped_script="$(yq e -r ".capabilities.\"$cap\".script // \"\"" "$MAP")"

  [[ "$mapped_plugin" == "$plugin" ]] || fail "capability_map plugin mismatch for $cap (expected=$plugin actual=$mapped_plugin)"
  [[ "$mapped_script" == "$expected_script" ]] || fail "capability_map script mismatch for $cap (expected=$expected_script actual=$mapped_script)"
  [[ -x "$ROOT/ops/plugins/$plugin/bin/$expected_script" ]] || fail "missing executable script: ops/plugins/$plugin/bin/$expected_script"
done

while IFS= read -r label; do
  [[ -n "$label" ]] || continue
  template="$(yq e -r ".scheduler.label_to_template.\"$label\" // \"\"" "$CONTRACT")"
  runtime_script="$(yq e -r ".scheduler.label_to_runtime_script.\"$label\" // \"\"" "$CONTRACT")"

  [[ -n "$template" ]] || fail "missing template mapping for label $label"
  [[ -n "$runtime_script" ]] || fail "missing runtime script mapping for label $label"
  [[ -f "$ROOT/$template" ]] || fail "missing launchd template file: $template"
  [[ -f "$ROOT/$runtime_script" ]] || fail "missing runtime script file: $runtime_script"

  yq e -e ".labels[] | select(.label == \"$label\" and .template_source == \"spine\")" "$REGISTRY" >/dev/null 2>&1 \
    || fail "launchd scheduler registry missing spine label entry: $label"

  registry_template="$(yq e -r ".labels[] | select(.label == \"$label\") | .template_path" "$REGISTRY" | head -n1)"
  [[ "$registry_template" == "$template" ]] || fail "registry template mismatch for $label (expected=$template actual=$registry_template)"

done < <(yq e -r '.scheduler.required_labels[]' "$CONTRACT")

schema_version="$(yq e -r '.product.schema_version // ""' "$CONTRACT")"
[[ "$schema_version" == "1.0" ]] || fail "contract product.schema_version must be 1.0"

echo "D380 PASS: cc-benefits runtime parity lock clean"
