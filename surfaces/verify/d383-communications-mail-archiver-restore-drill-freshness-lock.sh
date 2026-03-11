#!/usr/bin/env bash
# TRIAGE: Enforce governed mail-archiver restore-proof freshness and PASS status before communications restore posture can be considered green.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/mail.archiver.backup.contract.yaml"
SCHEDULE="$ROOT/ops/bindings/backup.schedule.yaml"
CAPABILITIES="$ROOT/ops/capabilities.yaml"
CAP_MAP="$ROOT/ops/bindings/capability_map.yaml"
ROUTING="$ROOT/ops/bindings/routing.dispatch.yaml"
PLUGIN_MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"

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
need_file "$CONTRACT"
need_file "$SCHEDULE"
need_file "$CAPABILITIES"
need_file "$CAP_MAP"
need_file "$ROUTING"
need_file "$PLUGIN_MANIFEST"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D383 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

expected_capability="communications.mailarchiver.restore.drill"
expected_receipt_glob="$(yq -r '.restore_proof.canonical_receipt_glob // ""' "$CONTRACT")"
expected_freshness_days="$(yq -r '.restore_proof.freshness_days // 35' "$CONTRACT")"

[[ "$expected_receipt_glob" != "" && "$expected_receipt_glob" != "null" ]] || err "contract missing restore_proof.canonical_receipt_glob"
[[ "$expected_freshness_days" =~ ^[0-9]+$ ]] || err "contract freshness_days is not numeric"

cap_exists="$(yq -r ".capabilities.\"$expected_capability\".command // \"\"" "$CAPABILITIES")"
[[ -n "$cap_exists" && "$cap_exists" != "null" ]] || err "capabilities.yaml missing $expected_capability"

cap_map_script="$(yq -r ".capabilities.\"$expected_capability\".script // \"\"" "$CAP_MAP")"
[[ "$cap_map_script" == "communications-mail-archiver-restore-drill" ]] || err "capability_map missing communications-mail-archiver-restore-drill mapping"

routing_command="$(yq -r ".dispatch.\"$expected_capability\".target.command // \"\"" "$ROUTING")"
[[ "$routing_command" == "./ops/plugins/domains/communications/bin/communications-mail-archiver-restore-drill" ]] || err "routing.dispatch missing communications restore drill route"

manifest_has_cap="$(yq -r '.plugins[] | select(.name == "communications") | .capabilities[]' "$PLUGIN_MANIFEST" | grep -Fx "$expected_capability" || true)"
[[ -n "$manifest_has_cap" ]] || err "plugin manifest missing $expected_capability"

schedule_enabled="$(yq -r '.jobs[] | select(.id == "mail-archiver-restore-drill-monthly") | (.enabled // false) | tostring' "$SCHEDULE")"
[[ "$schedule_enabled" == "true" ]] || err "mail-archiver-restore-drill-monthly is not enabled"

schedule_capability="$(yq -r '.jobs[] | select(.id == "mail-archiver-restore-drill-monthly") | .capability_ref // ""' "$SCHEDULE")"
[[ "$schedule_capability" == "$expected_capability" ]] || err "mail-archiver-restore-drill-monthly capability_ref mismatch"

schedule_glob="$(yq -r '.jobs[] | select(.id == "mail-archiver-restore-drill-monthly") | .receipt_glob // ""' "$SCHEDULE")"
[[ "$schedule_glob" == "$expected_receipt_glob" ]] || err "mail-archiver-restore-drill-monthly receipt_glob mismatch"

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

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    match="$(yq -r ".comparison.\"$key\".match // \"\"" "$latest_receipt")"
    [[ "$match" == "true" ]] || err "latest restore drill receipt has non-matching comparison for $key: $latest_receipt"
  done < <(yq -r '.restore_proof.comparison_targets[]' "$CONTRACT" | sed 's/^public\.__EFMigrationsHistory$/public_ef_migrations_history_rows/; s/^mail_archiver\.ArchivedEmails$/mail_archiver_archived_emails_rows/; s/^mail_archiver\.MailAccounts$/mail_archiver_mail_accounts_rows/; s/^mail_archiver\.Users$/mail_archiver_users_rows/')
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D383 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D383 PASS: communications mail-archiver restore drill is governed, fresh, and passing"
