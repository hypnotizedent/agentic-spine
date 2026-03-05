#!/usr/bin/env bash
# D368: planned-loop-review-freshness-lock
# Flag planned loops that have no next_review or stale review dates (>14 days past due).
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "$HOME/code/agentic-spine"
}

ROOT="$(resolve_root)"
SCOPES_DIR="$ROOT/mailroom/state/loop-scopes"

[[ -d "$SCOPES_DIR" ]] || { echo "D368 PASS: no loop scopes directory"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "D368 FAIL: missing dependency python3" >&2; exit 1; }

python3 - "$SCOPES_DIR" <<'PY'
import datetime as dt
import re
import sys
from pathlib import Path

scopes_dir = Path(sys.argv[1])
today = dt.date.today()
stale_after_days = 14
failures: list[str] = []
checked = 0

fm_re = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)

for scope in sorted(scopes_dir.glob("*.scope.md")):
    text = scope.read_text(encoding="utf-8", errors="replace")
    m = fm_re.search(text)
    if not m:
        continue
    fm = m.group(1)
    status = ""
    loop_id = scope.stem.replace(".scope", "")
    next_review = ""
    for raw in fm.splitlines():
        line = raw.strip()
        if not line or ":" not in line:
            continue
        k, v = line.split(":", 1)
        key = k.strip()
        val = v.strip().strip('"')
        if key == "status":
            status = val
        elif key == "loop_id" and val:
            loop_id = val
        elif key == "next_review":
            next_review = val
    if status != "planned":
        continue
    checked += 1
    if not next_review:
        failures.append(f"{loop_id}: status=planned requires next_review")
        continue
    try:
        review_date = dt.date.fromisoformat(next_review)
    except ValueError:
        failures.append(f"{loop_id}: invalid next_review '{next_review}' (expected YYYY-MM-DD)")
        continue
    if review_date < (today - dt.timedelta(days=stale_after_days)):
        failures.append(
            f"{loop_id}: next_review {next_review} is stale (> {stale_after_days} days past due)"
        )

if failures:
    for item in failures:
        print(f"D368 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print(f"D368 PASS: planned loop review freshness valid (planned_loops_checked={checked})")
PY
