#!/usr/bin/env bash
# TRIAGE: Check backup SSOT for stale entries. No secret printing in backup scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_SCRIPT="$ROOT/ops/plugins/backup/bin/backup-status"
BINDING_FILE="$ROOT/ops/bindings/backup.inventory.yaml"

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

# 2c) Runtime unit schema checks
missing_required_count="$(yq e -r '[.runtime_units[] | select((.unit_id // "") == "" or (.kind // "") == "" or (.hostname // "") == "" or (.backup_profile // "") == "" or (.data_class // "") == "" or (.destination_lane // "") == "" or (.schedule_class // "") == "" or (.restore_class // "") == "" or ((.inventory_targets // []) | length) == 0)] | length' "$BINDING_FILE" 2>/dev/null || echo 999)"
[[ "$missing_required_count" == "0" ]] || fail "runtime_units contain rows missing required fields"

media_exclusion_count="$(yq e -r '.runtime_units[] | select(.hostname == "download-stack" or .hostname == "streaming-stack") | (.exclude_paths // [])[]?' "$BINDING_FILE" 2>/dev/null | grep -Ec '^/mnt/media(/|$)' || true)"
[[ "$media_exclusion_count" -ge 2 ]] || fail "media runtime units must explicitly exclude /mnt/media payload lane"

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
