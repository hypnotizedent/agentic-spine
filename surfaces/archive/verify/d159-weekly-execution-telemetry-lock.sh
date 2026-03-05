#!/usr/bin/env bash
# TRIAGE: Regenerate weekly telemetry artifacts and register generated dashboard surface.
# D159: weekly execution telemetry lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/weekly.execution.telemetry.contract.yaml"
CHECKER="$ROOT/ops/plugins/evidence/bin/weekly-execution-telemetry"
INDEX_PATH="$ROOT/docs/governance/_index.yaml"
DASHBOARD_PATH="$ROOT/docs/governance/generated/telemetry/WEEKLY_EXECUTION_DASHBOARD.md"

fail() {
  echo "D159 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing telemetry contract: $CONTRACT"
[[ -x "$CHECKER" ]] || fail "missing telemetry checker script: $CHECKER"
[[ -f "$INDEX_PATH" ]] || fail "missing docs index: $INDEX_PATH"
[[ -f "$DASHBOARD_PATH" ]] || fail "missing dashboard: $DASHBOARD_PATH"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

check_json=""
if ! check_json="$($CHECKER --check --json 2>/dev/null)"; then
  fail "weekly-execution-telemetry --check failed"
fi

python3 - "$CONTRACT" "$INDEX_PATH" "$DASHBOARD_PATH" "$check_json" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

contract_path = Path(sys.argv[1])
index_path = Path(sys.argv[2])
dashboard_path = Path(sys.argv[3])
check_json = sys.argv[4]

errors: list[str] = []


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


try:
    contract = load_yaml(contract_path)
except Exception as exc:
    print(f"D159 FAIL: contract parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(contract, dict):
    errors.append("telemetry contract root must be a map")
else:
    for key in ("reporting_window_days", "trend_window_weeks", "required_signals", "freshness_sla_hours"):
        if key not in contract:
            errors.append(f"telemetry contract missing required key: {key}")

try:
    check_data = json.loads(check_json)
except Exception as exc:
    errors.append(f"telemetry checker json parse error: {exc}")
    check_data = {}

latest_week_file = Path(str(check_data.get("latest_week_file", "")).strip()) if check_data else Path()
trend_entries = check_data.get("trend_entries")

if check_data.get("status") != "ok":
    errors.append(f"telemetry checker status not ok: {check_data.get('status')!r}")

if not latest_week_file or not latest_week_file.exists():
    errors.append("latest weekly telemetry file missing")

if not isinstance(trend_entries, int) or trend_entries < 0:
    errors.append("telemetry checker trend_entries missing or invalid")

try:
    index_data = load_yaml(index_path)
except Exception as exc:
    errors.append(f"docs index parse error: {exc}")
    index_data = {}

files = set()
documents = index_data.get("documents")
if isinstance(documents, list):
    for row in documents:
        if isinstance(row, dict):
            files.add(str(row.get("file", "")).strip())
else:
    errors.append("docs/governance/_index.yaml documents must be a list")

required_dashboard_index = "generated/telemetry/WEEKLY_EXECUTION_DASHBOARD.md"
if required_dashboard_index not in files:
    errors.append(f"dashboard not registered in docs index: {required_dashboard_index}")

if latest_week_file.exists():
    try:
        latest = load_yaml(latest_week_file)
    except Exception as exc:
        errors.append(f"latest telemetry parse error: {exc}")
        latest = {}

    signals = latest.get("signals") if isinstance(latest, dict) else None
    if not isinstance(signals, dict):
        errors.append("latest telemetry missing signals map")
    else:
        required = contract.get("required_signals") if isinstance(contract, dict) else {}
        if not isinstance(required, dict):
            errors.append("contract required_signals must be a map")
        else:
            lock_gates = required.get("lock_gates") if isinstance(required.get("lock_gates"), list) else []
            lock_status = signals.get("lock_gates") if isinstance(signals.get("lock_gates"), dict) else {}
            if not isinstance(lock_status, dict):
                errors.append("latest telemetry missing signals.lock_gates map")
            else:
                missing_gates = [g for g in lock_gates if g not in lock_status]
                if missing_gates:
                    errors.append("latest telemetry missing lock gate signals: " + ", ".join(missing_gates))

            for key in (
                "verify_hygiene_weekly_status",
                "verify_core_status",
                "proposals_pending_count",
                "proposals_linkage_mismatch_count",
                "instant_ring_budget_delta_seconds",
            ):
                if key not in signals:
                    errors.append(f"latest telemetry missing required signal: {key}")

if errors:
    for err in errors:
        print(f"  FAIL: {err}", file=sys.stderr)
    print(f"D159 FAIL: weekly execution telemetry lock violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(
    "D159 PASS: weekly execution telemetry lock valid "
    f"(latest={latest_week_file.name} trend_entries={trend_entries})"
)
PY
