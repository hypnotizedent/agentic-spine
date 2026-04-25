#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIFT_BIN="$ROOT/ops/plugins/core/lifecycle/bin/standing-program-drift-check"
LIB_DIR="$ROOT/ops/plugins/core/lifecycle/lib"
BIRTH_BIN="$ROOT/ops/plugins/core/lifecycle/bin/standing-program-intervention-birth"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

watcher_json="$tmpdir/watcher.json"
metabolizer_json="$tmpdir/metabolizer.json"

python3 "$DRIFT_BIN" --json --label com.ronny.alerting-probe-cycle >"$watcher_json"
python3 "$DRIFT_BIN" --json --label com.ronny.operator-ingress-auto-metabolizer >"$metabolizer_json"

python3 - "$watcher_json" "$metabolizer_json" "$LIB_DIR" "$BIRTH_BIN" <<'PYEOF'
import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

watcher_path = Path(sys.argv[1])
metabolizer_path = Path(sys.argv[2])
lib_dir = Path(sys.argv[3])
birth_path = Path(sys.argv[4])

sys.path.insert(0, str(lib_dir))
import standing_program_exception_v1 as spx
import delegation_broker as db


def load_birth_module(path: Path):
    loader = importlib.machinery.SourceFileLoader("standing_program_intervention_birth", str(path))
    spec = importlib.util.spec_from_loader("standing_program_intervention_birth", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


birth = load_birth_module(birth_path)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


watcher = read_json(watcher_path)
metabolizer = read_json(metabolizer_path)

watcher_programs = watcher.get("programs", [])
metabolizer_programs = metabolizer.get("programs", [])
require(len(watcher_programs) == 1, "watcher drift check did not return exactly one program")
require(len(metabolizer_programs) == 1, "metabolizer drift check did not return exactly one program")
require(
    watcher_programs[0].get("enabled_trigger_types") == ["threshold_breach", "stale_failure"],
    "watcher enabled trigger types drifted",
)
require(
    metabolizer_programs[0].get("enabled_trigger_types") == ["missed_heartbeat"],
    "metabolizer enabled trigger types drifted",
)


def specimen(
    *,
    label: str,
    enabled: list[str],
    active: list[str],
    trigger_evaluations: dict,
    health: str,
    detail: str,
) -> dict:
    return {
        "label": label,
        "birth_mode": "standing_program",
        "intended_node_role": "watcher_node" if "alerting" in label else "execution_host",
        "source_node": "proxmox-home" if "alerting" in label else "ai-consolidation",
        "proof_channel": {},
        "proof_channel_type": "cycle_state" if "alerting" in label else "heartbeat",
        "proof_channel_host": "proxmox-home" if "alerting" in label else "ai-consolidation",
        "health": health,
        "detail": detail,
        "last_evidence_at_utc": spx.utc_now(),
        "staleness_seconds": 0,
        "stale_threshold_seconds": 300,
        "evidence_surface": "synthetic.verify",
        "evidence_ref": f"/tmp/{label}.json",
        "observed_status": health,
        "observed_counts": {},
        "enabled_trigger_types": enabled,
        "active_trigger_types": active,
        "drift_present": bool(active),
        "trigger_evaluations": trigger_evaluations,
    }


healthy_alert = specimen(
    label="com.ronny.alerting-probe-cycle",
    enabled=["threshold_breach", "stale_failure"],
    active=[],
    health="healthy",
    detail="healthy specimen",
    trigger_evaluations={
        "threshold_breach": {
            "enabled": True,
            "condition_met": False,
            "required_observations": 1,
            "evidence_surface": "synthetic.verify",
            "evidence_ref": "/tmp/watcher.json",
            "observed_status": "healthy",
            "observed_counts": {"consecutive_failures": 0, "threshold_failure_count_for_intervention": 5},
            "suggested_actions": ["none"],
        },
        "stale_failure": {
            "enabled": True,
            "condition_met": False,
            "required_observations": 2,
            "evidence_surface": "synthetic.verify",
            "evidence_ref": "/tmp/watcher.json",
            "observed_status": "healthy",
            "observed_counts": {"last_run_age_seconds": 60, "stale_threshold_seconds": 1200},
            "suggested_actions": ["none"],
        },
    },
)

stale_metabolizer = specimen(
    label="com.ronny.operator-ingress-auto-metabolizer",
    enabled=["missed_heartbeat"],
    active=["missed_heartbeat"],
    health="stale",
    detail="stale heartbeat specimen",
    trigger_evaluations={
        "missed_heartbeat": {
            "enabled": True,
            "condition_met": True,
            "required_observations": 2,
            "evidence_surface": "synthetic.verify",
            "evidence_ref": "/tmp/metabolizer.json",
            "observed_status": "stale",
            "observed_counts": {"heartbeat_age_seconds": 601, "stale_threshold_seconds": 300, "queue_pending": 0},
            "suggested_actions": ["check service"],
        },
    },
)

threshold_alert = specimen(
    label="com.ronny.alerting-probe-cycle",
    enabled=["threshold_breach", "stale_failure"],
    active=["threshold_breach"],
    health="failed",
    detail="threshold breach specimen",
    trigger_evaluations={
        "threshold_breach": {
            "enabled": True,
            "condition_met": True,
            "required_observations": 1,
            "evidence_surface": "synthetic.verify",
            "evidence_ref": "/tmp/watcher.json",
            "observed_status": "failed",
            "observed_counts": {"consecutive_failures": 5, "threshold_failure_count_for_intervention": 5},
            "suggested_actions": ["check timer"],
        },
        "stale_failure": {
            "enabled": True,
            "condition_met": False,
            "required_observations": 2,
            "evidence_surface": "synthetic.verify",
            "evidence_ref": "/tmp/watcher.json",
            "observed_status": "healthy",
            "observed_counts": {"last_run_age_seconds": 60, "stale_threshold_seconds": 1200},
            "suggested_actions": ["none"],
        },
    },
)

with tempfile.TemporaryDirectory(prefix="autonomous-exception-birth-v1-") as tmp_state:
    os.environ["SPINE_STATE"] = tmp_state
    Path(tmp_state, "interventions").mkdir(parents=True, exist_ok=True)

    result = birth.process_programs([healthy_alert], state_root=tmp_state, dry_run=False)
    require(result["birthed"] == 0, "healthy specimen birthed an intervention")

    states = spx.build_exception_specimen_states([stale_metabolizer], tmp_state)
    require(states[0]["operator_state"] == "standing_stale_or_degraded", "drift state did not surface before birth")

    first = birth.process_programs([stale_metabolizer], state_root=tmp_state, dry_run=False)
    require(first["birthed"] == 0, "first missed-heartbeat observation birthed too early")

    second = birth.process_programs([stale_metabolizer], state_root=tmp_state, dry_run=False)
    require(second["birthed"] == 1, "second missed-heartbeat observation did not birth exactly one packet")

    loop_id = "LOOP-VERIFY-AUTONOMOUS-EXCEPTION-BIRTH-V1-20260425"
    loop_scope_dir = Path(tmp_state) / "loop-scopes"
    loop_scope_dir.mkdir(parents=True, exist_ok=True)
    (loop_scope_dir / f"{loop_id}.scope.md").write_text(
        "---\n"
        f"loop_id: {loop_id}\n"
        "status: active\n"
        "owner: '@verify'\n"
        "scope: spine\n"
        "priority: high\n"
        "horizon: now\n"
        "execution_readiness: runnable\n"
        "execution_mode: single_worker\n"
        "objective: verify intervention delegation path\n"
        "---\n",
        encoding="utf-8",
    )
    _, metabolizer_doc = spx.find_open_intervention(
        tmp_state,
        "com.ronny.operator-ingress-auto-metabolizer",
        "missed_heartbeat",
    )
    require(metabolizer_doc is not None, "metabolizer intervention missing after birth")
    delegated = db.delegate(
        loop_id=loop_id,
        packet_id=str(metabolizer_doc.get("intervention_id")),
        state_root=tmp_state,
        objective="verify intervention delegation path",
        target_role="worker",
        delegator_terminal="VERIFY",
    )
    require(delegated.get("status") == "delegated", "intervention did not enter delegation broker")
    require(delegated.get("packet_kind") == "intervention", "broker did not classify intervention packet correctly")
    pickup = db.pickup(tmp_state, delegation_id=str(delegated["delegation_id"]), worker_terminal="VERIFY-WORKER")
    require(pickup.get("status") == "picked_up", "worker pickup failed")
    db.transition(tmp_state, str(delegated["delegation_id"]), "executing", wave_id="WAVE-VERIFY")
    db.transition(tmp_state, str(delegated["delegation_id"]), "landed", wave_id="WAVE-VERIFY", disposition="verify landed")
    _, landed_doc = spx.find_open_intervention(
        tmp_state,
        "com.ronny.operator-ingress-auto-metabolizer",
        "missed_heartbeat",
    )
    require(landed_doc is None, "landed intervention still counted as open")

    third = birth.process_programs([stale_metabolizer], state_root=tmp_state, dry_run=False)
    require(third["birthed"] == 0, "landed intervention rebirthed without reconfirmation")

    states = spx.build_exception_specimen_states([stale_metabolizer], tmp_state)
    require(states[0]["operator_state"] == "standing_stale_or_degraded", "post-landed drift state did not fall back to degraded without intervention")

    threshold = birth.process_programs([threshold_alert], state_root=tmp_state, dry_run=False)
    require(threshold["birthed"] == 1, "threshold breach did not birth immediately")

    path, doc = spx.find_open_intervention(tmp_state, "com.ronny.alerting-probe-cycle", "threshold_breach")
    require(path is not None and doc is not None, "threshold intervention not found after birth")
    doc["disposition"] = "landed"
    spx.atomic_write_yaml(path, doc)

    rebirth = birth.process_programs([threshold_alert], state_root=tmp_state, dry_run=False)
    require(rebirth["birthed"] == 1, "terminal disposition did not clear the threshold lock")

print("PASS: live evaluation surfaces resolved, dedupe held, birth/reset behavior held, and surface states matched")
PYEOF

echo "D434 PASS: autonomous exception birth V1 behavior held"
