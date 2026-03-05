#!/usr/bin/env bash
# TRIAGE: verify traffic index projection freshness + required field parity with role runtime contract.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
ROLE_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"

fail() {
  echo "D325 FAIL: $*" >&2
  exit 1
}

[[ -f "$ROLE_CONTRACT" ]] || fail "missing role runtime contract"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$ROOT" "$ROLE_CONTRACT" <<'PY'
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
role_path = Path(sys.argv[2])


def load_yaml(path: Path):
    raw = subprocess.check_output(["yq", "-o=json", ".", str(path)], text=True)
    return json.loads(raw)


role = load_yaml(role_path)
errors = []

traffic = role.get("traffic_index") if isinstance(role.get("traffic_index"), dict) else {}
state_rel = str(traffic.get("state_file") or "").strip()
required_fields = traffic.get("required_fields") if isinstance(traffic.get("required_fields"), list) else []

if not state_rel:
    errors.append("role.runtime traffic_index.state_file missing")

if not required_fields:
    errors.append("role.runtime traffic_index.required_fields missing")

state_candidates = []
if state_rel:
    state_candidates.append(root / state_rel)
    # Fallback for runtime materialization from canonical root when running in a worktree.
    state_candidates.append(Path.home() / "code" / "agentic-spine" / state_rel)

state_path = None
for candidate in state_candidates:
    if candidate.is_file():
        state_path = candidate
        break

if errors:
    for err in errors:
        print(f"D325 FAIL: {err}", file=sys.stderr)
    raise SystemExit(1)

if state_path is None:
    print("D325 PASS: traffic index projection not materialized in this checkout (runtime-only)")
    raise SystemExit(0)

raw = state_path.read_text(encoding="utf-8").strip()
if not raw:
    raise SystemExit("D325 FAIL: traffic index file is empty")

try:
    doc = json.loads(raw)
except Exception:
    # YAML fallback through yq for mixed environments.
    doc = load_yaml(state_path)

if not isinstance(doc, dict):
    raise SystemExit("D325 FAIL: traffic index document must be an object")

updated_at = str(doc.get("updated_at") or "").strip()
if not updated_at:
    raise SystemExit("D325 FAIL: traffic index updated_at missing")

try:
    updated_dt = dt.datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
except Exception:
    raise SystemExit(f"D325 FAIL: traffic index updated_at invalid: {updated_at}")

age_hours = (dt.datetime.now(dt.timezone.utc) - updated_dt).total_seconds() / 3600.0
if age_hours > 48:
    raise SystemExit(f"D325 FAIL: traffic index is stale ({age_hours:.1f}h > 48h)")

items = doc.get("items")
if not isinstance(items, list):
    raise SystemExit("D325 FAIL: traffic index items must be a list")

for i, row in enumerate(items):
    if not isinstance(row, dict):
        raise SystemExit(f"D325 FAIL: traffic index items[{i}] is not an object")
    missing = []
    for field in required_fields:
        if field not in row:
            missing.append(field)
            continue
        value = row.get(field)
        if value is None:
            missing.append(field)
            continue
        if field == "claimed_paths":
            if not isinstance(value, list) or not value:
                missing.append(field)
            continue
        if field == "blockers":
            if not isinstance(value, list):
                missing.append(field)
            continue
        if field == "next_role":
            # Close-state rows may terminate without a next role.
            if str(row.get("status") or "").strip().lower() == "closed":
                continue
            if str(value).strip() == "":
                missing.append(field)
            continue
        if isinstance(value, str) and value.strip() == "":
            missing.append(field)
    if missing:
        raise SystemExit(f"D325 FAIL: traffic index items[{i}] missing required fields: {', '.join(missing)}")

print(f"D325 PASS: traffic index freshness/field parity valid (items={len(items)}, age_hours={age_hours:.1f})")
PY
