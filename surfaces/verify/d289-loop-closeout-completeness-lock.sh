#!/usr/bin/env bash
# TRIAGE: enforce deterministic loop closeout primitive wiring and contract completeness.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/loop.closeout.contract.yaml"
SCRIPT="$ROOT/ops/plugins/loops/bin/loop-closeout-finalize"
CAPS="$ROOT/ops/capabilities.yaml"
MAP="$ROOT/ops/bindings/capability_map.yaml"
DISPATCH="$ROOT/ops/bindings/routing.dispatch.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"

fail() {
  echo "D289 FAIL: $*" >&2
  exit 1
}

for f in "$CONTRACT" "$SCRIPT" "$CAPS" "$MAP" "$DISPATCH" "$MANIFEST"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

[[ -x "$SCRIPT" ]] || fail "script is not executable: $SCRIPT"

# Contract shape
for path in \
  '.validation.run_key_regex' \
  '.validation.min_required_run_keys' \
  '.fix_to_lock.p0_p1_severities' \
  '.protected_lanes.loops' \
  '.protected_lanes.gaps' \
  '.closeout_receipts.directory'; do
  value="$(yq e -r "$path // \"\"" "$CONTRACT")"
  [[ -n "$value" && "$value" != "null" ]] || fail "contract missing required field: $path"
done

# Capability wiring parity
rg -n '^\s*loop\.closeout\.finalize:' "$CAPS" >/dev/null 2>&1 || fail "capabilities.yaml missing loop.closeout.finalize"
rg -n '^\s*loop\.closeout\.finalize:' "$MAP" >/dev/null 2>&1 || fail "capability_map.yaml missing loop.closeout.finalize"
rg -n '^\s*loop\.closeout\.finalize:' "$DISPATCH" >/dev/null 2>&1 || fail "routing.dispatch.yaml missing loop.closeout.finalize"
rg -n 'loop\.closeout\.finalize' "$MANIFEST" >/dev/null 2>&1 || fail "plugin manifest missing loop.closeout.finalize"

# Script self-check
"$SCRIPT" --self-check >/dev/null

echo "D289 PASS: loop closeout completeness lock enforced"
