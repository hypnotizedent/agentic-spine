#!/usr/bin/env bash
# TRIAGE: keep friction intake queue fresh by failing when queued items age beyond SLA.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
QUEUE_FILE="${VERIFY_FRICTION_QUEUE_FILE:-$ROOT/mailroom/state/friction-queue.ndjson}"
SLA_HOURS="${VERIFY_FRICTION_QUEUE_SLA_HOURS:-24}"

fail() {
  echo "D307 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$QUEUE_FILE" "$SLA_HOURS" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

queue = Path(sys.argv[1]).expanduser()
try:
    sla_hours = float(sys.argv[2])
except Exception:
    sla_hours = 24.0
if sla_hours <= 0:
    sla_hours = 24.0

if not queue.exists():
    print(f"D307 PASS: friction queue absent (no backlog) path={queue}")
    raise SystemExit(0)

now = datetime.now(timezone.utc)
rows = []
for raw in queue.read_text(encoding="utf-8", errors="replace").splitlines():
    line = raw.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    if isinstance(obj, dict):
        rows.append(obj)

queued_total = 0
stale = []
invalid_time = []

for row in rows:
    status = str(row.get("status", "queued")).strip().lower()
    if status != "queued":
        continue
    queued_total += 1

    raw_first = str(row.get("first_seen_utc", "")).strip()
    friction_id = str(row.get("friction_id", "<unknown>")).strip()
    if not raw_first:
        invalid_time.append((friction_id, "missing"))
        continue

    try:
        first_seen = datetime.fromisoformat(raw_first.replace("Z", "+00:00")).astimezone(timezone.utc)
    except Exception:
        invalid_time.append((friction_id, raw_first))
        continue

    age_h = (now - first_seen).total_seconds() / 3600.0
    if age_h > sla_hours:
        stale.append((friction_id, round(age_h, 1), str(row.get("capability", ""))))

if invalid_time:
    for friction_id, raw_first in invalid_time[:20]:
        print(
            f"D307 FAIL: queued friction {friction_id} has invalid first_seen_utc='{raw_first}'",
            file=sys.stderr,
        )
    if len(invalid_time) > 20:
        print(f"D307 FAIL: ... and {len(invalid_time) - 20} more invalid queued timestamps", file=sys.stderr)
    raise SystemExit(1)

if stale:
    for friction_id, age_h, capability in stale[:20]:
        cap_text = f" capability={capability}" if capability else ""
        print(
            f"D307 FAIL: queued friction {friction_id} is stale age_hours={age_h}{cap_text}",
            file=sys.stderr,
        )
    if len(stale) > 20:
        print(f"D307 FAIL: ... and {len(stale) - 20} more stale queued items", file=sys.stderr)
    raise SystemExit(1)

print(
    f"D307 PASS: friction queue healthy (queued={queued_total} stale=0 threshold_hours={sla_hours:g})"
)
PY
