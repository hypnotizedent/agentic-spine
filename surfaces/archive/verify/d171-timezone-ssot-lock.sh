#!/usr/bin/env bash
# TRIAGE: Ensure all governed timezone fields match the canonical SSOT in tenant.profile.yaml (runtime.timezone). Does NOT touch UTC machine timestamps.
# D171: timezone ssot lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH="${SPINE_WORKBENCH:-$HOME/code/workbench}"
PROFILE="$ROOT/ops/bindings/tenant.profile.yaml"
LAUNCHD_CONTRACT="$ROOT/ops/bindings/launchd.runtime.contract.yaml"
LAUNCHD_REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"

fail() {
  echo "D171 FAIL: $*" >&2
  exit 1
}

[[ -f "$PROFILE" ]] || fail "missing tenant profile: $PROFILE"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"
command -v jq >/dev/null 2>&1 || fail "missing required tool: jq"
command -v plutil >/dev/null 2>&1 || fail "missing required tool: plutil"

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

# ── Launchd runtime timezone env parity ──

if [[ -f "$LAUNCHD_CONTRACT" ]]; then
  contract_schedule_tz="$(yq -r '.schedule_timezone // ""' "$LAUNCHD_CONTRACT")"
  check "$LAUNCHD_CONTRACT" "schedule_timezone" "$contract_schedule_tz"

  launchd_source_dir="$(yq -r '.paths.source_dir // ""' "$LAUNCHD_CONTRACT")"
  if [[ -n "$launchd_source_dir" && -d "$launchd_source_dir" ]]; then
    required_env_tz="$(yq -r '.required_env[]?' "$LAUNCHD_CONTRACT" 2>/dev/null | grep -Fx 'TZ' || true)"
    required_env_operator_tz="$(yq -r '.required_env[]?' "$LAUNCHD_CONTRACT" 2>/dev/null | grep -Fx 'SPINE_OPERATOR_TZ' || true)"

    [[ -n "$required_env_tz" ]] || {
      echo "D171 MISMATCH: $LAUNCHD_CONTRACT required_env must include TZ" >&2
      ERRORS=$((ERRORS + 1))
    }
    [[ -n "$required_env_operator_tz" ]] || {
      echo "D171 MISMATCH: $LAUNCHD_CONTRACT required_env must include SPINE_OPERATOR_TZ" >&2
      ERRORS=$((ERRORS + 1))
    }

    while IFS= read -r -d '' plist; do
      tz_val="$(plutil -convert json -o - "$plist" 2>/dev/null | jq -r '.EnvironmentVariables.TZ // ""')"
      operator_tz_val="$(plutil -convert json -o - "$plist" 2>/dev/null | jq -r '.EnvironmentVariables.SPINE_OPERATOR_TZ // ""')"
      check "$plist" "EnvironmentVariables.TZ" "$tz_val"
      check "$plist" "EnvironmentVariables.SPINE_OPERATOR_TZ" "$operator_tz_val"
    done < <(find "$launchd_source_dir" -maxdepth 1 -type f -name 'com.ronny*.plist' -print0)
  fi
fi

if [[ -f "$LAUNCHD_REGISTRY" ]]; then
  registry_schedule_tz="$(yq -r '.schedule_timezone // ""' "$LAUNCHD_REGISTRY")"
  check "$LAUNCHD_REGISTRY" "schedule_timezone" "$registry_schedule_tz"
fi

# ── Host system timezone parity (launchd schedule parsing uses host timezone) ──

system_tz=""
if command -v systemsetup >/dev/null 2>&1; then
  systemsetup_out="$(systemsetup -gettimezone 2>/dev/null || true)"
  if [[ "$systemsetup_out" =~ Time[[:space:]]Zone:[[:space:]](.+) ]]; then
    system_tz="${BASH_REMATCH[1]}"
  fi
fi

if [[ -z "$system_tz" && -L "/etc/localtime" ]]; then
  localtime_target="$(readlink /etc/localtime || true)"
  if [[ "$localtime_target" == *"/zoneinfo/"* ]]; then
    system_tz="${localtime_target##*/zoneinfo/}"
  fi
fi

if [[ -z "$system_tz" ]]; then
  echo "D171 MISMATCH: could not determine host system timezone (systemsetup denied and /etc/localtime unresolved)" >&2
  ERRORS=$((ERRORS + 1))
else
  check "host-system" "timezone" "$system_tz"
fi

# ── Result ──

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS timezone mismatch(es) found against SSOT ($SSOT_TZ)"
fi

echo "D171 PASS: all governed timezone fields match SSOT ($SSOT_TZ)"
