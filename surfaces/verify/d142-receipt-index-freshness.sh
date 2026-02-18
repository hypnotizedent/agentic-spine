#!/usr/bin/env bash
# TRIAGE: Build/refresh receipt index via receipts.index.build and rotate stale receipts (receipts.rotate --execute) so index age <=48h and no sessions exceed 2x retention.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INDEX_FILE="$ROOT/ops/plugins/evidence/state/receipt-index.yaml"
POLICY_FILE="$ROOT/ops/bindings/evidence.retention.policy.yaml"
RECEIPTS_DIR="$ROOT/receipts/sessions"

fail() {
  echo "D142 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v python3 >/dev/null 2>&1 || fail "required tool missing: python3"

if [[ ! -f "$INDEX_FILE" ]]; then
  "$ROOT/ops/plugins/evidence/bin/receipts-index-build" --index "$INDEX_FILE" --quiet || fail "unable to build missing index"
fi

[[ -f "$INDEX_FILE" ]] || fail "receipt index missing: $INDEX_FILE"

updated_at="$(yq -r '.updated_at_utc // .watermark.updated_at_utc // ""' "$INDEX_FILE")"
[[ -n "$updated_at" && "$updated_at" != "null" ]] || fail "index missing updated_at_utc/watermark"

age_hours="$(python3 - "$updated_at" <<'PY'
import datetime as dt
import sys
raw = sys.argv[1]
try:
    t = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
except Exception:
    print(-1)
    raise SystemExit(0)
now = dt.datetime.now(dt.timezone.utc)
print(int((now - t).total_seconds() // 3600))
PY
)"

[[ "$age_hours" =~ ^-?[0-9]+$ ]] || fail "could not compute index age"
(( age_hours >= 0 )) || fail "invalid index timestamp format: $updated_at"
(( age_hours < 48 )) || fail "index is stale (${age_hours}h old; max=47h)"

retention_days="$(yq -r '.retention_classes.session_receipts.retention_days // 30' "$POLICY_FILE" 2>/dev/null || echo 30)"
[[ "$retention_days" =~ ^[0-9]+$ ]] || retention_days=30
threshold=$(( retention_days * 2 ))

stale_count=0
if [[ -d "$RECEIPTS_DIR" ]]; then
  stale_count="$(find "$RECEIPTS_DIR" -maxdepth 1 -mindepth 1 -type d -mtime +"$threshold" 2>/dev/null | wc -l | tr -d ' ')"
fi
[[ "$stale_count" =~ ^[0-9]+$ ]] || stale_count=0

if (( stale_count > 0 )); then
  fail "${stale_count} receipt session dirs exceed 2x retention (${threshold} days)"
fi

entries="$(yq -r '.entries | length' "$INDEX_FILE" 2>/dev/null || echo 0)"
echo "D142 PASS: receipt index fresh (${age_hours}h) with $entries entries; stale_over_2x_retention=$stale_count"
