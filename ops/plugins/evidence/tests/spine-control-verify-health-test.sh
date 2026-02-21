#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/evidence/bin/spine-control"

[[ -x "$BIN" ]] || { echo "FAIL: spine-control script missing or not executable" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL: missing python3" >&2; exit 1; }

python3 - "$ROOT" <<'PY'
import importlib.machinery
import importlib.util
from pathlib import Path
import sys


def expect(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


root = Path(sys.argv[1]).resolve()
path = root / "ops/plugins/evidence/bin/spine-control"
loader = importlib.machinery.SourceFileLoader("spine_control_mod", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

# Case 1: historical failures are superseded by newer passes -> no current verify risk.
events_historical_only = [
    {"capability": "verify.core.run", "status": "done", "created_at": "2026-02-21T04:10:00Z", "summary": "core pass"},
    {"capability": "verify.pack.run", "status": "done", "created_at": "2026-02-21T04:05:00Z", "summary": "pack pass"},
    {"capability": "verify.core.run", "status": "failed", "created_at": "2026-02-21T03:55:00Z", "summary": "core fail"},
    {"capability": "verify.pack.run", "status": "failed", "created_at": "2026-02-21T03:45:00Z", "summary": "pack fail"},
]
health_hist = module.summarize_verify_health(events_historical_only)
expect(health_hist["verify_failed_runs"] == 2, "historical verify failures count should be retained")
expect(health_hist["verify_current_failed_runs"] == 0, "historical failures should not remain current")
expect(health_hist["core_verify_latest_status"] == "done", "latest core verify should be done")
expect(health_hist["core_verify_needs_attention"] is False, "core verify should not require attention")

tick_hist = {
    "data": {
        "summary": {"open_loops": 0, "open_gaps": 0, "pending_proposals": 0, "active_alerts": 0, "active_handoffs": 0},
        "loops": [],
        "gaps": [],
        "alerts": {"total_alerts": 0, "active_domains": []},
        "proposals": {"pending": 0},
        "timeline": health_hist,
    }
}
plan_hist = module.build_plan_payload(tick_hist)
hist_action_ids = [row.get("action_id", "") for row in plan_hist.get("data", {}).get("actions", [])]
expect("A40-core-verify-rerun" not in hist_action_ids, "A40 should not trigger on historical-only failures")

# Case 2: latest core verify failed -> rerun action must trigger.
events_core_failed = [
    {"capability": "verify.core.run", "status": "failed", "created_at": "2026-02-21T05:10:00Z", "summary": "core fail"},
    {"capability": "verify.core.run", "status": "done", "created_at": "2026-02-21T04:10:00Z", "summary": "core pass"},
]
health_core_failed = module.summarize_verify_health(events_core_failed)
expect(health_core_failed["verify_current_failed_runs"] == 1, "latest failed core verify should remain current")
expect(health_core_failed["core_verify_needs_attention"] is True, "latest failed core verify should require attention")

tick_core_failed = {
    "data": {
        "summary": {"open_loops": 0, "open_gaps": 0, "pending_proposals": 0, "active_alerts": 0, "active_handoffs": 0},
        "loops": [],
        "gaps": [],
        "alerts": {"total_alerts": 0, "active_domains": []},
        "proposals": {"pending": 0},
        "timeline": health_core_failed,
    }
}
plan_core_failed = module.build_plan_payload(tick_core_failed)
core_failed_action_ids = [row.get("action_id", "") for row in plan_core_failed.get("data", {}).get("actions", [])]
expect("A40-core-verify-rerun" in core_failed_action_ids, "A40 should trigger when latest core verify failed")

print("PASS: spine-control verify health denoise")
PY
