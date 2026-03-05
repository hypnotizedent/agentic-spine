#!/usr/bin/env bash
# TRIAGE: Detect stale top-level runtime scripts that are not referenced by any launchd template.
# D298: orphan runtime script detection lock
# Fail if a top-level ops/runtime/*.sh script is not referenced by any
# launchd runtime template command path.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RUNTIME_DIR="$ROOT/ops/runtime"
PLIST_DIR="$ROOT/ops/runtime/launchd"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"

fail() {
  echo "D298 FAIL: $*" >&2
  exit 1
}

[[ -d "$RUNTIME_DIR" ]] || fail "runtime dir missing: $RUNTIME_DIR"
[[ -d "$PLIST_DIR" ]] || fail "launchd plist dir missing: $PLIST_DIR"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"
command -v plutil >/dev/null 2>&1 || fail "missing dependency: plutil"
[[ -f "$REGISTRY" ]] || fail "launchd scheduler registry missing: $REGISTRY"

violations=0
scripts_checked=0
plists_checked=0

for script in "$RUNTIME_DIR"/*.sh; do
  [[ -f "$script" ]] || continue
  scripts_checked=$((scripts_checked + 1))
  rel="ops/runtime/$(basename "$script")"

  if ! rg -n --fixed-strings "$rel" "$PLIST_DIR"/*.plist >/dev/null 2>&1; then
    echo "D298 HIT: orphan runtime script (no launchd template reference): $rel" >&2
    violations=$((violations + 1))
  fi
done

# Reverse direction: every governed spine launchd template must be represented
# in the scheduler registry, and every registry spine template path must exist.
for plist in "$PLIST_DIR"/com.ronny*.plist; do
  [[ -f "$plist" ]] || continue
  plists_checked=$((plists_checked + 1))
  label="$(plutil -convert json -o - "$plist" 2>/dev/null | jq -r '.Label // ""')"
  if [[ -z "$label" ]]; then
    echo "D298 HIT: launchd template missing Label: ${plist#$ROOT/}" >&2
    violations=$((violations + 1))
    continue
  fi
  if ! yq e -r ".labels[] | select(.label == \"$label\" and .template_source == \"spine\") | .label" "$REGISTRY" | grep -Fxq "$label"; then
    echo "D298 HIT: launchd template missing registry mapping: ${plist#$ROOT/} (label=$label)" >&2
    violations=$((violations + 1))
  fi
done

while IFS= read -r template_path; do
  [[ -n "$template_path" ]] || continue
  if [[ ! -f "$ROOT/$template_path" ]]; then
    echo "D298 HIT: registry spine template_path missing on disk: $template_path" >&2
    violations=$((violations + 1))
  fi
done < <(yq e -r '.labels[] | select(.template_source == "spine") | .template_path // ""' "$REGISTRY")

if [[ "$scripts_checked" -eq 0 ]]; then
  fail "no runtime scripts found under $RUNTIME_DIR"
fi

if [[ "$violations" -gt 0 ]]; then
  fail "runtime/template orphans detected=${violations} scripts_checked=${scripts_checked} plists_checked=${plists_checked}"
fi

echo "D298 PASS: no orphan runtime assets (scripts_checked=${scripts_checked} plists_checked=${plists_checked})"
