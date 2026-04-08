#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCHEDULE="$ROOT/ops/bindings/domains/backup/backup.schedule.yaml"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "G7 FAIL: missing dependency: $1" >&2
    exit 2
  }
}

need_cmd yq
need_cmd python3

[[ -f "$SCHEDULE" ]] || {
  echo "G7 FAIL: missing backup schedule: $SCHEDULE" >&2
  exit 2
}

freshness_days_for() {
  case "$1" in
    monthly*) echo 35 ;;
    quarterly*) echo 95 ;;
    weekly*) echo 9 ;;
    daily*) echo 2 ;;
    *) echo 35 ;;
  esac
}

printf "%-36s %-8s %-12s %s\n" "job" "result" "freshness" "detail"

failures=0
checked=0

while IFS=$'\t' read -r job_id schedule_class receipt_glob; do
  [[ -n "$job_id" ]] || continue
  checked=$((checked + 1))

  freshness_days="$(freshness_days_for "$schedule_class")"
  latest_receipt="$(python3 - "$SPINE_OUTBOX" "$receipt_glob" <<'PY'
import glob, os, sys
outbox_root, pattern = sys.argv[1], sys.argv[2]
pattern = pattern.replace("mailroom/outbox", outbox_root, 1)
matches = [p for p in glob.glob(pattern) if os.path.isfile(p)]
if not matches:
    raise SystemExit(1)
matches.sort(key=lambda p: os.path.getmtime(p), reverse=True)
print(matches[0])
PY
)" || latest_receipt=""

  if [[ -z "$latest_receipt" ]]; then
    printf "%-36s %-8s %-12s %s\n" "$job_id" "FAIL" "${freshness_days}d" "missing receipt"
    failures=$((failures + 1))
    continue
  fi

  result="$(yq e -r '.result // ""' "$latest_receipt" 2>/dev/null || true)"
  generated_at="$(yq e -r '.generated_at // ""' "$latest_receipt" 2>/dev/null || true)"
  age_days="$(
    python3 - "$generated_at" <<'PY'
from datetime import datetime, timezone
import sys
value = sys.argv[1]
if not value:
    print(999)
    raise SystemExit(0)
try:
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
except ValueError:
    print(999)
    raise SystemExit(0)
if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)
delta = datetime.now(timezone.utc) - dt.astimezone(timezone.utc)
print(int(delta.total_seconds() // 86400))
PY
  )"

  if [[ "$result" != "PASS" ]]; then
    printf "%-36s %-8s %-12s %s\n" "$job_id" "FAIL" "${freshness_days}d" "latest result=${result:-missing}"
    failures=$((failures + 1))
    continue
  fi
  if [[ ! "$age_days" =~ ^[0-9]+$ || "$age_days" -gt "$freshness_days" ]]; then
    printf "%-36s %-8s %-12s %s\n" "$job_id" "FAIL" "${freshness_days}d" "receipt age=${age_days}d"
    failures=$((failures + 1))
    continue
  fi

  printf "%-36s %-8s %-12s %s\n" "$job_id" "PASS" "${age_days}d" "$latest_receipt"
done < <(
  yq e -r '
    .jobs[]
    | select(.kind == "restore-drill" and (.enabled // false) == true)
    | [ .id, (.schedule_class // ""), (.receipt_glob // "") ]
    | @tsv
  ' "$SCHEDULE"
)

if [[ "$checked" -eq 0 ]]; then
  echo "G7 FAIL: no enabled restore-drill jobs found" >&2
  exit 1
fi

if [[ "$failures" -gt 0 ]]; then
  echo "G7 FAIL: restore drill freshness failures=${failures}/${checked}" >&2
  exit 1
fi

echo "G7 PASS: restore drills current (${checked})"
