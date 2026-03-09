#!/usr/bin/env bash
# TRIAGE: Enforce governed home backup restore-proof freshness and PASS status before home backup posture can be considered green.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCHEDULE="$ROOT/ops/bindings/backup.schedule.yaml"
CAPABILITIES="$ROOT/ops/capabilities.yaml"
CAP_MAP="$ROOT/ops/bindings/capability_map.yaml"
INVENTORY="$ROOT/ops/bindings/backup.inventory.yaml"

ERRORS=0
err() {
  echo "  FAIL: $*" >&2
  ERRORS=$((ERRORS + 1))
}

need_file() {
  [[ -f "$1" ]] || err "missing file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "missing command: $1"
}

need_cmd yq
need_cmd python3
need_file "$SCHEDULE"
need_file "$CAPABILITIES"
need_file "$CAP_MAP"
need_file "$INVENTORY"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D385 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

expected_capability="backup.home.restore.drill"
expected_receipt_glob="mailroom/outbox/reports/restore-drills/backup-home-restore-drill-*.yaml"
expected_freshness_days=95

cap_exists="$(yq -r ".capabilities.\"$expected_capability\".command // \"\"" "$CAPABILITIES")"
[[ -n "$cap_exists" && "$cap_exists" != "null" ]] || err "capabilities.yaml missing $expected_capability"

cap_map_script="$(yq -r ".capabilities.\"$expected_capability\".script // \"\"" "$CAP_MAP")"
[[ "$cap_map_script" == "backup-home-restore-drill" ]] || err "capability_map missing backup-home-restore-drill mapping"

schedule_enabled="$(yq -r '.jobs[] | select(.id == "home-restore-drill-quarterly") | (.enabled // false) | tostring' "$SCHEDULE")"
[[ "$schedule_enabled" == "true" ]] || err "home-restore-drill-quarterly is not enabled"

schedule_capability="$(yq -r '.jobs[] | select(.id == "home-restore-drill-quarterly") | .capability_ref // ""' "$SCHEDULE")"
[[ "$schedule_capability" == "$expected_capability" ]] || err "home-restore-drill-quarterly capability_ref mismatch"

schedule_glob="$(yq -r '.jobs[] | select(.id == "home-restore-drill-quarterly") | .receipt_glob // ""' "$SCHEDULE")"
[[ "$schedule_glob" == "$expected_receipt_glob" ]] || err "home-restore-drill-quarterly receipt_glob mismatch"

inventory_pihole_enabled="$(yq -r '.targets[] | select(.name == "home-lxc-105-pihole-primary") | .enabled // false' "$INVENTORY")"
[[ "$inventory_pihole_enabled" == "true" ]] || err "backup.inventory home-lxc-105-pihole-primary not enabled"

inventory_ha_enabled="$(yq -r '.targets[] | select(.name == "home-vm-100-ha-primary") | .enabled // false' "$INVENTORY")"
[[ "$inventory_ha_enabled" == "true" ]] || err "backup.inventory home-vm-100-ha-primary not enabled"

latest_receipt="$(python3 - "$ROOT" "$expected_receipt_glob" <<'PY'
import glob, os, sys
root, pattern = sys.argv[1], sys.argv[2]
matches = glob.glob(os.path.join(root, pattern))
matches = [m for m in matches if os.path.isfile(m)]
if not matches:
    sys.exit(1)
matches.sort(key=lambda p: os.path.getmtime(p), reverse=True)
print(matches[0])
PY
)" || latest_receipt=""

if [[ -z "$latest_receipt" ]]; then
  err "no restore drill receipt found for pattern $expected_receipt_glob"
else
  result="$(yq -r '.result // ""' "$latest_receipt")"
  [[ "$result" == "PASS" ]] || err "latest restore drill receipt is not PASS: $latest_receipt"

  generated_at="$(yq -r '.generated_at // ""' "$latest_receipt")"
  age_days="$(python3 - "$generated_at" <<'PY'
from datetime import datetime, timezone
import sys
value = sys.argv[1]
if not value:
    print(-1)
    raise SystemExit(0)
ts = datetime.fromisoformat(value.replace("Z", "+00:00"))
delta = datetime.now(timezone.utc) - ts
print(int(delta.total_seconds() // 86400))
PY
)"
  if [[ "$age_days" -lt 0 ]]; then
    err "latest restore drill receipt missing generated_at: $latest_receipt"
  elif [[ "$age_days" -gt "$expected_freshness_days" ]]; then
    err "latest restore drill receipt is stale (${age_days}d > ${expected_freshness_days}d): $latest_receipt"
  fi

  pihole_config_exists="$(yq -r '.comparison.pihole_config_exists // ""' "$latest_receipt")"
  [[ "$pihole_config_exists" == "true" ]] || err "latest restore drill receipt has pihole_config_exists != true: $latest_receipt"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D385 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D385 PASS: home backup restore drill is governed, fresh, and passing"
