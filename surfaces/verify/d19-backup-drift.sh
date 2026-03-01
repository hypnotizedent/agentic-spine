#!/usr/bin/env bash
# TRIAGE: Check backup SSOT for stale entries. No secret printing in backup scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_SCRIPT="$ROOT/ops/plugins/backup/bin/backup-status"
BINDING_FILE="$ROOT/ops/bindings/backup.inventory.yaml"
POSTURE_FILE="$ROOT/ops/bindings/backup.posture.snapshot.yaml"

fail(){ echo "D19 FAIL: $*" >&2; exit 1; }

# 1) Capability script must exist + be executable
[[ -f "$CAP_SCRIPT" ]] || fail "missing $CAP_SCRIPT"
[[ -x "$CAP_SCRIPT" ]] || fail "not executable: $CAP_SCRIPT"

# 2) Binding file must exist
[[ -f "$BINDING_FILE" ]] || fail "missing $BINDING_FILE"

# 2b) Backup model sections must exist
runtime_units_count="$(yq e -r '.runtime_units | length' "$BINDING_FILE" 2>/dev/null || echo 0)"
[[ "$runtime_units_count" =~ ^[0-9]+$ ]] || runtime_units_count=0
[[ "$runtime_units_count" -gt 0 ]] || fail "runtime_units model missing in backup.inventory"

model_profile="$(yq e -r '.model.profile_version // ""' "$BINDING_FILE" 2>/dev/null || true)"
[[ -n "$model_profile" && "$model_profile" != "null" ]] || fail "model.profile_version missing"

tz_name="$(yq e -r '.defaults.timezone // ""' "$BINDING_FILE" 2>/dev/null || true)"
[[ "$tz_name" == "America/New_York" ]] || fail "defaults.timezone must be America/New_York (got: ${tz_name:-unset})"

admission_states_count="$(yq e -r '.model.backup_admission_states | length' "$BINDING_FILE" 2>/dev/null || echo 0)"
[[ "$admission_states_count" =~ ^[0-9]+$ ]] || admission_states_count=0
[[ "$admission_states_count" -ge 2 ]] || fail "model.backup_admission_states missing (expected planned + production_ready)"

# 2c) Runtime unit schema checks
missing_required_count="$(yq e -r '[.runtime_units[] | select((.unit_id // "") == "" or (.kind // "") == "" or (.hostname // "") == "" or (.backup_profile // "") == "" or (.backup_admission_state // "") == "" or (.data_class // "") == "" or (.destination_lane // "") == "" or (.schedule_class // "") == "" or (.restore_class // "") == "" or ((.inventory_targets // []) | length) == 0)] | length' "$BINDING_FILE" 2>/dev/null || echo 999)"
[[ "$missing_required_count" == "0" ]] || fail "runtime_units contain rows missing required fields"

invalid_admission_count="$(yq e -r '[.runtime_units[] | select((.backup_admission_state // "") != "planned" and (.backup_admission_state // "") != "production_ready")] | length' "$BINDING_FILE" 2>/dev/null || echo 999)"
[[ "$invalid_admission_count" == "0" ]] || fail "runtime_units contain invalid backup_admission_state values"

media_exclusion_count="$(yq e -r '.runtime_units[] | select(.hostname == "download-stack" or .hostname == "streaming-stack") | (.exclude_paths // [])[]?' "$BINDING_FILE" 2>/dev/null | grep -Ec '^/mnt/media(/|$)' || true)"
[[ "$media_exclusion_count" -ge 2 ]] || fail "media runtime units must explicitly exclude /mnt/media payload lane"

# 2d) Destination lanes must carry budget guardrails
lanes_with_budget_missing="$(yq e -r '[.model.destination_lanes[] | select((.max_total_gb // null) == null or (.max_file_count // null) == null)] | length' "$BINDING_FILE" 2>/dev/null || echo 999)"
[[ "$lanes_with_budget_missing" == "0" ]] || fail "destination_lanes missing max_total_gb/max_file_count budget guardrails"

# 2e) Backup posture snapshot must exist and be fresh (<= 26h)
[[ -f "$POSTURE_FILE" ]] || fail "missing backup posture projection: $POSTURE_FILE"
posture_generated="$(yq e -r '.generated_at_utc // ""' "$POSTURE_FILE" 2>/dev/null || true)"
[[ -n "$posture_generated" && "$posture_generated" != "null" ]] || fail "backup posture projection missing generated_at_utc"
posture_age_hours="$(
python3 - <<PY
from datetime import datetime, timezone
ts = "${posture_generated}"
try:
    gen = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    age = (datetime.now(timezone.utc) - gen).total_seconds() / 3600.0
    print(int(age))
except Exception:
    print(999)
PY
)"
[[ "$posture_age_hours" =~ ^[0-9]+$ ]] || posture_age_hours=999
[[ "$posture_age_hours" -le 26 ]] || fail "backup posture projection stale (${posture_age_hours}h old; expected <=26h)"

restore_missing_total="$(yq e -r '.summary.restore_coverage_missing_total // 999' "$POSTURE_FILE" 2>/dev/null || echo 999)"
[[ "$restore_missing_total" == "0" ]] || fail "restore coverage missing for enabled targets (missing_total=$restore_missing_total)"

lane_over_budget_total="$(yq e -r '.summary.lane_over_budget_total // 999' "$POSTURE_FILE" 2>/dev/null || echo 999)"
[[ "$lane_over_budget_total" == "0" ]] || fail "lane budget exceeded (lane_over_budget_total=$lane_over_budget_total)"

lane_collect_errors_total="$(yq e -r '.summary.lane_collect_errors_total // 999' "$POSTURE_FILE" 2>/dev/null || echo 999)"
[[ "$lane_collect_errors_total" == "0" ]] || fail "lane budget telemetry collection has errors (lane_collect_errors_total=$lane_collect_errors_total)"

# 3) No legacy/runtime smell coupling in backup plugin surface
if rg -n --hidden --no-ignore-vcs -S \
  '(ronny-ops|~/agent|/agent/|LaunchAgents|launchd|\.plist\b|cron\b|state/|/state/|receipts/|/receipts/)' \
  "$CAP_SCRIPT" >/dev/null; then
  fail "legacy/runtime smell markers found in backup-status"
fi

# 4) Forbid destructive/mutating commands (backup.status is inventory-only)
# Allow: ssh, ls, stat, find, test, cat, head, tail, awk, sed, grep, yq, date
if rg -n -S \
  '\b(rm|mv|cp|rsync|scp|restic|zfs|rclone|dd|mkfs|mount|umount|truncate)\b' \
  "$CAP_SCRIPT" >/dev/null; then
  fail "destructive/mutating command found in backup-status"
fi

# 5) HTTP method guard (should be none here, but keep consistent with other API gates)
if rg -n -S '\bcurl\b.*\s-X\s*(POST|PUT|PATCH|DELETE)\b' "$CAP_SCRIPT" >/dev/null; then
  fail "mutating HTTP method found"
fi

# 6) Token leak guardrail (never print secrets)
if rg -n -S '(echo|printf).*(TOKEN|SECRET|API_KEY|PASSWORD|INFISICAL_|CLOUDFLARE_)|set\s+-x' "$CAP_SCRIPT" >/dev/null; then
  fail "potential secret printing/debug tracing found"
fi

echo "D19 PASS: backup.status drift surface locked"
