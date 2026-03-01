#!/usr/bin/env bash
# TRIAGE: Keep runtime script names in parity with launchd labels and scheduler registry template paths.
# D297: runtime script registry name parity lock
# Enforce 1:1 naming parity between ops/runtime/*.sh, launchd plist templates,
# and launchd.scheduler.registry label+template mappings.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RUNTIME_DIR="$ROOT/ops/runtime"
PLIST_DIR="$ROOT/ops/runtime/launchd"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"

fail() {
  echo "D297 FAIL: $*" >&2
  exit 1
}

[[ -d "$RUNTIME_DIR" ]] || fail "runtime dir missing: $RUNTIME_DIR"
[[ -d "$PLIST_DIR" ]] || fail "launchd plist dir missing: $PLIST_DIR"
[[ -f "$REGISTRY" ]] || fail "scheduler registry missing: $REGISTRY"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v /usr/libexec/PlistBuddy >/dev/null 2>&1 || fail "missing dependency: PlistBuddy"

violations=0
scripts_checked=0

for script in "$RUNTIME_DIR"/*.sh; do
  [[ -f "$script" ]] || continue
  scripts_checked=$((scripts_checked + 1))

  base="$(basename "$script" .sh)"
  expected_label="com.ronny.${base}"
  expected_plist_rel="ops/runtime/launchd/${expected_label}.plist"
  expected_plist_abs="$ROOT/$expected_plist_rel"

  if [[ ! -f "$expected_plist_abs" ]]; then
    echo "D297 HIT: missing plist template for runtime script ops/runtime/${base}.sh -> $expected_plist_rel" >&2
    violations=$((violations + 1))
    continue
  fi

  plist_label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$expected_plist_abs" 2>/dev/null || true)"
  if [[ "$plist_label" != "$expected_label" ]]; then
    echo "D297 HIT: plist label mismatch for ${expected_plist_rel} (expected=${expected_label}, actual=${plist_label:-missing})" >&2
    violations=$((violations + 1))
  fi

  registry_template="$(yq e -r ".labels[] | select(.label == \"$expected_label\") | .template_path" "$REGISTRY" 2>/dev/null || true)"
  if [[ -z "$registry_template" || "$registry_template" == "null" ]]; then
    echo "D297 HIT: scheduler registry missing label entry for $expected_label" >&2
    violations=$((violations + 1))
  elif [[ "$registry_template" != "$expected_plist_rel" ]]; then
    echo "D297 HIT: scheduler registry template mismatch for $expected_label (expected=${expected_plist_rel}, actual=${registry_template})" >&2
    violations=$((violations + 1))
  fi

done

if [[ "$scripts_checked" -eq 0 ]]; then
  fail "no runtime scripts found under $RUNTIME_DIR"
fi

if [[ "$violations" -gt 0 ]]; then
  fail "runtime script registry name parity violations=${violations} scripts_checked=${scripts_checked}"
fi

echo "D297 PASS: runtime script registry name parity clean (scripts_checked=${scripts_checked})"
