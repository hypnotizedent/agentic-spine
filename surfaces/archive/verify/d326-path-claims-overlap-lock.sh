#!/usr/bin/env bash
# TRIAGE: detect overlapping active path claims that violate non-overlap contract.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
ROLE_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"

fail() {
  echo "D326 FAIL: $*" >&2
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
claims_cfg = role.get("path_claims") if isinstance(role.get("path_claims"), dict) else {}
state_rel = str(claims_cfg.get("state_file") or "").strip()
require_non_overlap = claims_cfg.get("require_non_overlapping_active_claims") is True

if not state_rel:
    raise SystemExit("D326 FAIL: role.runtime path_claims.state_file missing")
if not require_non_overlap:
    raise SystemExit("D326 FAIL: role.runtime path_claims.require_non_overlapping_active_claims must be true")

candidates = [root / state_rel, Path.home() / "code" / "agentic-spine" / state_rel]
state_path = next((p for p in candidates if p.is_file()), None)
if state_path is None:
    print("D326 PASS: path claims projection not materialized in this checkout (runtime-only)")
    raise SystemExit(0)

raw = state_path.read_text(encoding="utf-8").strip()
if not raw:
    raise SystemExit("D326 FAIL: path claims state file is empty")

try:
    doc = json.loads(raw)
except Exception:
    doc = load_yaml(state_path)

claims = doc.get("claims") if isinstance(doc, dict) else None
if not isinstance(claims, list):
    raise SystemExit("D326 FAIL: path claims document missing claims[] list")

active_statuses = {"active", "claimed", "open", "in_progress"}
active_claims = []
for row in claims:
    if not isinstance(row, dict):
        continue
    status = str(row.get("status") or "").strip().lower()
    if status not in active_statuses:
        continue
    paths = row.get("claimed_paths") if isinstance(row.get("claimed_paths"), list) else []
    if not paths:
        continue
    expires_at = str(row.get("expires_at") or "").strip()
    created_at = str(row.get("created_at") or "").strip()
    if not expires_at or not created_at:
        raise SystemExit(f"D326 FAIL: active claim {row.get('claim_id', '?')} missing created_at/expires_at")
    try:
        start = dt.datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        end = dt.datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
    except Exception:
        raise SystemExit(f"D326 FAIL: active claim {row.get('claim_id', '?')} has invalid timestamps")
    active_claims.append(
        {
            "claim_id": str(row.get("claim_id") or "unknown"),
            "paths": {str(p) for p in paths if str(p)},
            "start": start,
            "end": end,
        }
    )

violations = []
for i in range(len(active_claims)):
    for j in range(i + 1, len(active_claims)):
        a = active_claims[i]
        b = active_claims[j]
        overlap_paths = sorted(a["paths"].intersection(b["paths"]))
        if not overlap_paths:
            continue
        latest_start = max(a["start"], b["start"])
        earliest_end = min(a["end"], b["end"])
        if latest_start < earliest_end:
            violations.append(
                f"{a['claim_id']} overlaps {b['claim_id']} on {', '.join(overlap_paths)}"
            )

if violations:
    for line in violations:
        print(f"D326 FAIL: {line}", file=sys.stderr)
    raise SystemExit(1)

print(f"D326 PASS: no overlapping active path claims (active_claims={len(active_claims)})")
PY
