#!/usr/bin/env bash
# TRIAGE: High-churn parity lock for ops/plugins/MANIFEST.yaml.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
CAPS="$ROOT/ops/capabilities.yaml"

fail() {
  echo "D279 FAIL: $*" >&2
  exit 1
}

for f in "$MANIFEST" "$CAPS"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

plugin_count="$(yq e '.plugins | length' "$MANIFEST")"
[[ "$plugin_count" -gt 0 ]] || err "manifest has zero plugins"

for ((i=0; i<plugin_count; i++)); do
  name="$(yq e -r ".plugins[$i].name // \"\"" "$MANIFEST")"
  path="$(yq e -r ".plugins[$i].path // \"\"" "$MANIFEST")"
  [[ -n "$name" ]] || { err "plugin[$i] missing name"; continue; }
  [[ -n "$path" ]] || { err "plugin '$name' missing path"; continue; }
  [[ -d "$ROOT/$path" ]] || err "plugin '$name' path missing: $path"

  mapfile -t scripts < <(yq e -r ".plugins[$i].scripts[]? // \"\"" "$MANIFEST" | sed '/^$/d')
  for s in "${scripts[@]}"; do
    [[ -f "$ROOT/$path/$s" ]] || err "plugin '$name' missing script file: $path/$s"
  done

  mapfile -t capabilities < <(yq e -r ".plugins[$i].capabilities[]? // \"\"" "$MANIFEST" | sed '/^$/d')
  for cap in "${capabilities[@]}"; do
    yq e -r ".capabilities.\"$cap\".command // \"\"" "$CAPS" | grep -q . || err "plugin '$name' capability missing in ops/capabilities.yaml: $cap"
  done

done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D279 PASS: plugins manifest high-churn parity lock enforced"
