#!/usr/bin/env bash
# TRIAGE: ensure only snapshot-projection-apply writes tracked snapshot bindings.
# D359: snapshot-writepath-promoter-guard
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "${BASH_SOURCE[0]%/*/*}"
}

ROOT="$(resolve_root)"

fail() {
  echo "D359 FAIL: $*" >&2
  exit 1
}

PROMOTER_PATH="ops/plugins/snapshot/bin/snapshot-projection-apply"

# The 5 tracked snapshot capabilities that write to ops/bindings/
TRACKED_CAPS=(
  "ha-inventory-snapshot-build"
  "network.home.dhcp.audit"
  "media-content-snapshot-refresh"
  "network-inventory-snapshot-build"
  "ha.z2m.devices.snapshot"
)

[[ -f "$ROOT/$PROMOTER_PATH" ]] || fail "promoter script missing: $PROMOTER_PATH"

violations=0

# Check 1: No plugin script should default MODE to "apply"
echo "D359 INFO: check 1 — scanning ops/plugins/ for default-apply violations"
while IFS= read -r script; do
  rel="${script#$ROOT/}"
  [[ "$rel" == "$PROMOTER_PATH" ]] && continue
  if grep -qE '^MODE="apply"' "$script" 2>/dev/null; then
    echo "D359 HIT: script defaults to MODE=apply: $rel" >&2
    violations=$((violations + 1))
  fi
done < <(find "$ROOT/ops/plugins" -type f \( -name "*.legacy" -o -name "*.sh" \) 2>/dev/null)

# Check 2: All 5 tracked snapshot capabilities must be registered as safety=read-only
echo "D359 INFO: check 2 — verifying tracked snapshot capabilities are read-only"
for cap in "${TRACKED_CAPS[@]}"; do
  cap_escaped=$(echo "$cap" | sed 's/\./\\./g')
  safety=$(grep -A8 "^  ${cap_escaped}:" "$ROOT/ops/capabilities.yaml" 2>/dev/null | grep "safety:" | head -1 | awk '{print $2}') || true
  if [[ "$safety" != "read-only" ]]; then
    echo "D359 HIT: tracked snapshot capability '$cap' has safety=$safety (must be read-only)" >&2
    violations=$((violations + 1))
  fi
done

# Check 3: The promoter itself must be registered as safety=mutating with manual approval
echo "D359 INFO: check 3 — verifying promoter registration"
promoter_block=$(grep -A12 "snapshot\.projection\.apply:" "$ROOT/ops/capabilities.yaml" 2>/dev/null | head -13) || true
if [[ -z "$promoter_block" ]]; then
  echo "D359 HIT: snapshot.projection.apply not found in capabilities.yaml" >&2
  violations=$((violations + 1))
else
  if ! echo "$promoter_block" | grep -q "safety: mutating"; then
    echo "D359 HIT: snapshot.projection.apply must be registered as safety=mutating" >&2
    violations=$((violations + 1))
  fi
  if ! echo "$promoter_block" | grep -q "approval: manual"; then
    echo "D359 HIT: snapshot.projection.apply must require manual approval" >&2
    violations=$((violations + 1))
  fi
fi

# Check 4: No scheduled runtime job directly invokes tracked snapshot caps with --apply
echo "D359 INFO: check 4 — scanning runtime jobs for direct --apply invocations"
if [[ -d "$ROOT/ops/runtime" ]]; then
  while IFS= read -r jobfile; do
    rel="${jobfile#$ROOT/}"
    # Only check files that contain --apply
    grep -q "\-\-apply" "$jobfile" 2>/dev/null || continue
    for cap in "${TRACKED_CAPS[@]}"; do
      cap_escaped=$(echo "$cap" | sed 's/\./\\./g')
      if grep -qE "${cap_escaped}[[:space:]].*--apply|--apply[[:space:]].*${cap_escaped}|${cap_escaped}[[:space:]]+--[[:space:]]+--apply" "$jobfile" 2>/dev/null; then
        echo "D359 HIT: runtime job invokes $cap with --apply: $rel" >&2
        violations=$((violations + 1))
      fi
    done
  done < <(find "$ROOT/ops/runtime" -type f \( -name "*.sh" -o -name "*.py" \) 2>/dev/null)
fi

# Check 5: LaunchAgent plists must not invoke tracked snapshot caps with --apply
echo "D359 INFO: check 5 — scanning LaunchAgent plists for --apply invocations"
if [[ -d "$ROOT/ops/runtime/launchd" ]]; then
  while IFS= read -r plist; do
    rel="${plist#$ROOT/}"
    grep -q "\-\-apply" "$plist" 2>/dev/null || continue
    for cap in "${TRACKED_CAPS[@]}"; do
      cap_escaped=$(echo "$cap" | sed 's/\./\\./g')
      if grep -qE "${cap_escaped}" "$plist" 2>/dev/null; then
        echo "D359 HIT: LaunchAgent plist invokes tracked snapshot cap with --apply: $rel" >&2
        violations=$((violations + 1))
      fi
    done
  done < <(find "$ROOT/ops/runtime/launchd" -type f -name "*.plist" 2>/dev/null)
fi

if [[ "$violations" -gt 0 ]]; then
  fail "snapshot writepath promoter guard violations=${violations}"
fi

echo "D359 PASS: all tracked snapshot writes are channeled through snapshot.projection.apply"
