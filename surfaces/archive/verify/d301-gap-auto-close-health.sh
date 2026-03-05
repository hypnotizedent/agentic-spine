#!/usr/bin/env bash
# TRIAGE: Ensure gap auto-close streak state exists and no long-stale eligible gaps are stuck open.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GAPS_FILE="$ROOT/ops/bindings/operational.gaps.yaml"
STREAK_FILE="$ROOT/ops/plugins/verify/state/gate-pass-streak.json"

fail() {
  echo "D297 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

[[ -f "$GAPS_FILE" ]] || fail "missing gaps file: $GAPS_FILE"
[[ -f "$STREAK_FILE" ]] || fail "missing pass streak state: $STREAK_FILE"

yq e '.' "$GAPS_FILE" >/dev/null 2>&1 || fail "invalid YAML: $GAPS_FILE"
python3 - <<'PY' "$GAPS_FILE" "$STREAK_FILE"
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

gaps_file = Path(sys.argv[1])
streak_file = Path(sys.argv[2])

try:
    streak = json.loads(streak_file.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"D297 FAIL: invalid streak JSON: {exc}", file=sys.stderr)
    raise SystemExit(1)

try:
    raw = subprocess.run(
        ["yq", "e", "-o=json", ".", str(gaps_file)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    gaps_doc = json.loads(raw)
except Exception as exc:
    print(f"D301 FAIL: unable to parse gaps YAML: {exc}", file=sys.stderr)
    raise SystemExit(1)

now = datetime.now(timezone.utc)
violations = []
for gap in gaps_doc.get("gaps", []):
    if not isinstance(gap, dict):
        continue
    if str(gap.get("status", "")).strip().lower() != "open":
        continue
    if str(gap.get("discovered_by", "")).strip() != "verify-response-loop":
        continue
    if str(gap.get("severity", "")).strip().lower() != "medium":
        continue

    gid = str(gap.get("recovery_gate_id", "")).strip()
    if not gid:
        continue

    discovered_at = str(gap.get("discovered_at", "")).strip()
    if not discovered_at:
        continue

    try:
        discovered_dt = datetime.strptime(discovered_at, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError:
        continue

    age_days = (now - discovered_dt).days
    gate_state = streak.get(gid, {}) if isinstance(streak, dict) else {}
    gate_streak = int(gate_state.get("streak", 0) or 0)

    if age_days >= 7 and gate_streak >= 3:
        violations.append((str(gap.get("id", "<unknown>")), gid, age_days, gate_streak))

if violations:
    for gap_id, gid, age_days, gate_streak in violations[:20]:
        print(
            f"D301 FAIL: {gap_id} is open for {age_days}d while gate {gid} has pass streak={gate_streak} (expected auto-close)",
            file=sys.stderr,
        )
    if len(violations) > 20:
        print(f"D297 FAIL: ... and {len(violations) - 20} more stuck auto-close candidates", file=sys.stderr)
    raise SystemExit(1)

print("D301 PASS: gap auto-close health checks passed")
PY
