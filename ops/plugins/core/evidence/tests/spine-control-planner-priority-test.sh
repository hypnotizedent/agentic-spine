#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/core/evidence/bin/spine-control"

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
path = root / "ops/plugins/core/evidence/bin/spine-control"
loader = importlib.machinery.SourceFileLoader("spine_control_mod", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

trust_loop_id = "LOOP-SPINE-L1-SURVIVING-SET-AND-PLANNER-FIX-20260330"
tick_focus = {
    "data": {
        "summary": {
            "open_loops": 3,
            "open_gaps": 5,
            "pending_proposals": 0,
            "active_alerts": 0,
            "active_handoffs": 0,
        },
        "loops": [
            {
                "loop_id": "LOOP-MINT-LIFECYCLE-RESOLVER-20260314",
                "status": "active",
                "priority": "high",
                "scope": "mint",
                "objective": "Build governed customer job lifecycle resolution from quote packet.",
                "next_action": "",
            },
            {
                "loop_id": trust_loop_id,
                "status": "active",
                "priority": "high",
                "scope": "spine",
                "objective": "Settle the spine engine historical claim truthfully, reduce the surviving L1 canonical set, and fix planner ranking so trust-critical closure and reduction work wins.",
                "next_action": "spine_l1_surviving_set_and_planner_fix",
            },
            {
                "loop_id": "LOOP-IMMICH-VHS-BACKUP-UPLOAD-2PHASE-20260314",
                "status": "active",
                "priority": "medium",
                "scope": "immich",
                "objective": "Phase A: NAS to 730XD backup, Phase B: 730XD to Immich upload.",
                "next_action": "",
            },
        ],
        "gaps": [
            {
                "id": "GAP-OP-1",
                "severity": "high",
                "status": "open",
                "parent_loop": "LOOP-MINT-LIFECYCLE-RESOLVER-20260314",
                "description": "Mint intake bridge drift remains open.",
                "doc": "mailroom/state/friction-queue.ndjson",
            }
        ],
        "alerts": {"total_alerts": 11, "active_incident_alerts": 0, "active_domains": []},
        "aof_contract": {"marker_state": "current"},
        "forge": {"merge_candidates": []},
        "proposals": {"pending": 0},
        "timeline": {"core_verify_needs_attention": False},
    }
}

route_input, route_basis = module.derive_route_hint(tick_focus["data"]["loops"], tick_focus["data"]["gaps"])
expect(route_input == "workbench", "trust-critical control-plane corpus should route to workbench")
expect(route_basis == "control_plane_keyword", "trust-critical control-plane basis should be explicit")

plan_focus = module.build_plan_payload(tick_focus)
actions = plan_focus["data"]["actions"]
top_action = actions[0]
expect(top_action["action_id"] == f"A00-loop-progress-{trust_loop_id.lower()}", "trust-critical focus action should be first")
expect(top_action["route_target"]["capability"] == "loops.progress", "trust-critical focus action should use loops.progress")
expect(top_action["route_target"]["args"] == ["--loop", trust_loop_id], "trust-critical focus action should target the trust loop")
expect(plan_focus["data"]["recommended_action_ids"][0] == top_action["action_id"], "recommended actions should start with the trust-critical focus action")

loop_progress_actions = [row for row in actions if row.get("route_target", {}).get("capability") == "loops.progress"]
expect(loop_progress_actions[0]["route_target"]["args"][1] == trust_loop_id, "trust-critical loop should lead loop-progress ordering")

captured = {}


def fake_collect_tick_data(window_hours):
    expect(window_hours == 24, "cycle should forward window_hours to tick collection")
    return tick_focus


def fake_execute_plan_actions(action_ids, **kwargs):
    captured["action_ids"] = list(action_ids)
    return (
        {
            "status": "ok",
            "data": {
                "results": [],
                "artifacts": {},
            },
        },
        0,
    )


module.collect_tick_data = fake_collect_tick_data
module.execute_plan_actions = fake_execute_plan_actions
cycle_payload, rc = module.run_control_cycle(
    window_hours=24,
    max_actions=1,
    max_priority="P1",
    confirm_manual=False,
    allow_agent_tools=False,
    allow_unhealthy_agents=False,
    dry_run=True,
)
expect(rc == 0, "cycle selection stub should succeed")
expect(cycle_payload["data"]["selected_action_ids"] == [top_action["action_id"]], "cycle should select the trust-critical focus action first when constrained")
expect(captured["action_ids"] == [top_action["action_id"]], "cycle should execute the trust-critical focus action first")

print("PASS: spine-control planner priority")
PY
