#!/usr/bin/env bash
# TRIAGE: Ensure all governed timezone fields match the canonical SSOT in tenant.profile.yaml (runtime.timezone). Does NOT touch UTC machine timestamps.
# D171: timezone ssot lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH="${SPINE_WORKBENCH:-$HOME/code/workbench}"
PROFILE="$ROOT/ops/bindings/tenant.profile.yaml"

fail() {
  echo "D171 FAIL: $*" >&2
  exit 1
}

[[ -f "$PROFILE" ]] || fail "missing tenant profile: $PROFILE"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"

# Read SSOT timezone
SSOT_TZ="$(yq -r '.runtime.timezone // ""' "$PROFILE")"
[[ -n "$SSOT_TZ" ]] || fail "runtime.timezone not set in tenant profile"

ERRORS=0
check() {
  local file="$1" field="$2" actual="$3"
  if [[ "$actual" != "$SSOT_TZ" ]]; then
    echo "D171 MISMATCH: $file ($field) = '$actual' (expected '$SSOT_TZ')" >&2
    ERRORS=$((ERRORS + 1))
  fi
}

# ── Spine bindings ──

f="$ROOT/ops/bindings/calendar.global.yaml"
if [[ -f "$f" ]]; then
  val="$(yq -r '.timezone.default // ""' "$f")"
  check "$f" "timezone.default" "$val"
fi

f="$ROOT/ops/bindings/communications.policy.contract.yaml"
if [[ -f "$f" ]]; then
  val="$(yq -r '.delivery_windows.quiet_hours.timezone_default // ""' "$f")"
  check "$f" "delivery_windows.quiet_hours.timezone_default" "$val"
fi

f="$ROOT/ops/bindings/backup.inventory.yaml"
if [[ -f "$f" ]]; then
  val="$(yq -r '.defaults.timezone // ""' "$f")"
  check "$f" "defaults.timezone" "$val"
fi

f="$ROOT/ops/bindings/policy.autotune.contract.yaml"
if [[ -f "$f" ]]; then
  val="$(yq -r '.schedule.timezone // ""' "$f")"
  check "$f" "schedule.timezone" "$val"
fi

# ── Spine staged pihole compose ──

f="$ROOT/ops/staged/pihole/docker-compose.yml"
if [[ -f "$f" ]]; then
  val="$(grep 'TZ=' "$f" | head -1 | sed 's/.*TZ=//' | tr -d ' "'"'"'' || echo "")"
  check "$f" "TZ env" "$val"
fi

# ── Workbench pihole compose ──

f="$WORKBENCH/infra/compose/pihole/docker-compose.yml"
if [[ -f "$f" ]]; then
  val="$(grep 'TZ=' "$f" | head -1 | sed 's/.*TZ=//' | tr -d ' "'"'"'' || echo "")"
  check "$f" "TZ env" "$val"
fi

# ── Workbench Microsoft tools timezone defaults ──

f="$WORKBENCH/agents/microsoft/tools/microsoft_tools.py"
if [[ -f "$f" ]]; then
  # Check that the hardcoded fallback matches SSOT
  bad_defaults="$(grep -n 'default=.*UTC' "$f" | grep -i timezone || true)"
  if [[ -n "$bad_defaults" ]]; then
    echo "D171 MISMATCH: $f contains UTC timezone defaults:" >&2
    echo "$bad_defaults" >&2
    ERRORS=$((ERRORS + 1))
  fi
fi

# ── Result ──

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS timezone mismatch(es) found against SSOT ($SSOT_TZ)"
fi

echo "D171 PASS: all governed timezone fields match SSOT ($SSOT_TZ)"
