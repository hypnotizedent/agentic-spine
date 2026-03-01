#!/usr/bin/env bash
# TRIAGE: Detect stale top-level runtime scripts that are not referenced by any launchd template.
# D298: orphan runtime script detection lock
# Fail if a top-level ops/runtime/*.sh script is not referenced by any
# launchd runtime template command path.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RUNTIME_DIR="$ROOT/ops/runtime"
PLIST_DIR="$ROOT/ops/runtime/launchd"

fail() {
  echo "D298 FAIL: $*" >&2
  exit 1
}

[[ -d "$RUNTIME_DIR" ]] || fail "runtime dir missing: $RUNTIME_DIR"
[[ -d "$PLIST_DIR" ]] || fail "launchd plist dir missing: $PLIST_DIR"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

violations=0
scripts_checked=0

for script in "$RUNTIME_DIR"/*.sh; do
  [[ -f "$script" ]] || continue
  scripts_checked=$((scripts_checked + 1))
  rel="ops/runtime/$(basename "$script")"

  if ! rg -n --fixed-strings "$rel" "$PLIST_DIR"/*.plist >/dev/null 2>&1; then
    echo "D298 HIT: orphan runtime script (no launchd template reference): $rel" >&2
    violations=$((violations + 1))
  fi
done

if [[ "$scripts_checked" -eq 0 ]]; then
  fail "no runtime scripts found under $RUNTIME_DIR"
fi

if [[ "$violations" -gt 0 ]]; then
  fail "orphan runtime scripts detected=${violations} scripts_checked=${scripts_checked}"
fi

echo "D298 PASS: no orphan runtime scripts (scripts_checked=${scripts_checked})"
