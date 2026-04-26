#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIFT_BIN="$ROOT/ops/plugins/core/lifecycle/bin/standing-program-drift-check"
LIB_DIR="$ROOT/ops/plugins/core/lifecycle/lib"
BIRTH_BIN="$ROOT/ops/plugins/core/lifecycle/bin/standing-program-intervention-birth"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

drift_json="$tmpdir/drift.json"
python3 "$DRIFT_BIN" --json >"$drift_json"

python3 - "$drift_json" "$LIB_DIR" "$BIRTH_BIN" <<'PYEOF'
import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

drift_path = Path(sys.argv[1])
lib_dir = Path(sys.argv[2])
birth_path = Path(sys.argv[3])

sys.path.insert(0, str(lib_dir))
import delegation_broker as db
import standing_program_exception_v1 as spx


EXPECTED_LABELS = [
    "com.ronny.alerting-probe-cycle",
    "com.ronny.operator-ingress-auto-metabolizer",
    "com.ronny.domain-inventory-refresh-daily",
    "com.ronny.infra-core-smoke",
    "com.ronny.simplefin-daily-sync",
]
ROLLOUT_LABELS = [
    "com.ronny.domain-inventory-refresh-daily",
    "com.ronny.infra-core-smoke",
    "com.ronny.simplefin-daily-sync",
]
BLOCKED_LABELS = [
    "com.ronny.communications-alerts-dispatcher",
    "com.ronny.log-rotation-daily",
    "com.ronny.operator-storage-surface-sync",
    "com.ronny.finance-backup-weekly",
    "com.ronny.media-capacity-snapshot-daily",
]
EXPECTED_TRIGGERS = {
    "com.ronny.alerting-probe-cycle": ["threshold_breach", "stale_failure"],
    "com.ronny.operator-ingress-auto-metabolizer": ["missed_heartbeat"],
    "com.ronny.domain-inventory-refresh-daily": ["stale_failure"],
    "com.ronny.infra-core-smoke": ["stale_failure"],
    "com.ronny.simplefin-daily-sync": ["stale_failure"],
}


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


drift = read_json(drift_path)
labels = list(drift.get("labels") or [])
programs = list(drift.get("programs") or [])
by_label = {}
for program in programs:
    if isinstance(program, dict):
        label = str(program.get("label") or "").strip()
        if label:
            by_label[label] = program

require(set(labels) == set(EXPECTED_LABELS), f"bounded V1 label set drifted: {sorted(labels)}")
require(set(spx.V1_ALLOWED_LABELS.keys()) == set(EXPECTED_LABELS), "V1 allowed-label set drifted")

for label in EXPECTED_LABELS:
    require(label in by_label, f"drift check missing expected label: {label}")
    require(
        by_label[label].get("enabled_trigger_types") == EXPECTED_TRIGGERS[label],
        f"enabled trigger types drifted for {label}",
    )

for label in ROLLOUT_LABELS:
    require(
        by_label[label].get("proof_channel_type") == "runtime_telemetry",
        f"proof channel type drifted for {label}",
    )
    require(
        by_label[label].get("evidence_surface") == "host.launchd.scheduler.health.status",
        f"proof surface drifted for {label}",
    )

for blocked in BLOCKED_LABELS:
    require(blocked not in spx.V1_ALLOWED_LABELS, f"blocked label widened into scope: {blocked}")
    try:
        spx.v1_labels([blocked])
    except ValueError:
        pass
    else:
        raise SystemExit(f"blocked label unexpectedly accepted by v1_labels: {blocked}")


def rollout_specimen(
    *,
    label: str,
    condition_met: bool,
    observed_status: str,
    last_run_age_seconds: int,
    stale_threshold_seconds: int,
    cadence_seconds: int = 86400,
) -> dict:
    trigger = {
        "enabled": True,
        "condition_met": condition_met,
        "required_observations": 2,
        "evidence_surface": "host.launchd.scheduler.health.status",
        "evidence_ref": f"/opt/spine-logs/runtime-jobs.ndjson::{label}",
        "observed_status": observed_status,
        "observed_counts": {
            "scheduler_status": observed_status,
            "last_run_age_seconds": last_run_age_seconds,
            "stale_threshold_seconds": stale_threshold_seconds,
            "cadence_seconds": cadence_seconds,
            "last_exit_code": 0,
        },
        "suggested_actions": [
            "Inspect host.launchd.scheduler.health.status for the label row.",
            "Restore scheduled cadence execution for the workload on ai-consolidation.",
        ],
        "detail": (
            f"scheduler_status={observed_status} "
            f"last_run_age_seconds={last_run_age_seconds} "
            f"stale_threshold_seconds={stale_threshold_seconds}"
        ),
    }
    return {
        "label": label,
        "birth_mode": "standing_program",
        "intended_node_role": "execution_host",
        "source_node": "ai-consolidation",
        "proof_channel": {
            "type": "runtime_telemetry",
            "host": "ai-consolidation",
            "path": "/opt/spine-logs/runtime-jobs.ndjson",
            "label_match": label,
            "stale_threshold_seconds": 90000,
        },
        "proof_channel_type": "runtime_telemetry",
        "proof_channel_host": "ai-consolidation",
        "health": "stale" if condition_met else "healthy",
        "detail": trigger["detail"],
        "last_evidence_at_utc": spx.utc_now(),
        "staleness_seconds": last_run_age_seconds,
        "stale_threshold_seconds": stale_threshold_seconds,
        "evidence_surface": "host.launchd.scheduler.health.status",
        "evidence_ref": f"/opt/spine-logs/runtime-jobs.ndjson::{label}",
        "observed_status": observed_status,
        "observed_counts": dict(trigger["observed_counts"]),
        "enabled_trigger_types": ["stale_failure"],
        "active_trigger_types": ["stale_failure"] if condition_met else [],
        "drift_present": condition_met,
        "trigger_evaluations": {"stale_failure": trigger},
    }


with tempfile.TemporaryDirectory(prefix="autonomous-exception-birth-v1-") as tmp_state:
    os.environ["SPINE_STATE"] = tmp_state
    Path(tmp_state, "interventions").mkdir(parents=True, exist_ok=True)

    loop_id = "LOOP-VERIFY-AUTONOMOUS-EXCEPTION-BIRTH-V1-ROLLOUT-20260425"
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
        "objective: verify stale_failure rollout path\n"
        "---\n",
        encoding="utf-8",
    )

    for label in ROLLOUT_LABELS:
        healthy = rollout_specimen(
            label=label,
            condition_met=False,
            observed_status="ok",
            last_run_age_seconds=60,
            stale_threshold_seconds=173400,
        )
        healthy_result = birth.process_programs([healthy], state_root=tmp_state, dry_run=False)
        require(healthy_result["birthed"] == 0, f"healthy specimen birthed for {label}")

        stale = rollout_specimen(
            label=label,
            condition_met=True,
            observed_status="stale",
            last_run_age_seconds=200000,
            stale_threshold_seconds=173400,
        )

        pre_states = spx.build_exception_specimen_states([stale], tmp_state)
        require(
            pre_states[0]["operator_state"] == "standing_stale_or_degraded",
            f"pre-birth degraded state did not surface for {label}",
        )

        first = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
        require(first["birthed"] == 0, f"first stale observation birthed too early for {label}")

        second = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
        require(second["birthed"] == 1, f"second stale observation did not birth for {label}")

        third = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
        require(third["birthed"] == 0, f"duplicate stale poll birthed again for {label}")
        require(third["locked"] >= 1, f"duplicate stale poll was not lock-suppressed for {label}")

        path, doc = spx.find_open_intervention(tmp_state, label, "stale_failure")
        require(path is not None and doc is not None, f"open intervention missing for {label}")
        require(
            str(doc.get("dedupe_key") or "") == f"{label}::stale_failure",
            f"dedupe key drifted for {label}",
        )

        active_states = spx.build_exception_specimen_states([stale], tmp_state)
        require(
            active_states[0]["operator_state"] == "auto_birthed_intervention_active",
            f"intervention-active state did not surface for {label}",
        )
        require(
            bool(active_states[0]["manual_birth_not_needed"]),
            f"manual-birth suppression did not surface for {label}",
        )

        delegated = db.delegate(
            loop_id=loop_id,
            packet_id=str(doc.get("intervention_id")),
            state_root=tmp_state,
            objective=f"verify stale_failure rollout for {label}",
            target_role="worker",
            delegator_terminal="VERIFY",
        )
        require(delegated.get("status") == "delegated", f"delegation broker rejected {label}")
        require(delegated.get("packet_kind") == "intervention", f"broker packet kind drifted for {label}")

        pickup = db.pickup(tmp_state, delegation_id=str(delegated["delegation_id"]), worker_terminal="VERIFY-WORKER")
        require(pickup.get("status") == "picked_up", f"worker pickup failed for {label}")
        db.transition(tmp_state, str(delegated["delegation_id"]), "executing", wave_id=f"WAVE-VERIFY-{label}")
        db.transition(
            tmp_state,
            str(delegated["delegation_id"]),
            "landed",
            wave_id=f"WAVE-VERIFY-{label}",
            disposition="verify landed",
        )

        _, landed_doc = spx.find_open_intervention(tmp_state, label, "stale_failure")
        require(landed_doc is None, f"landed intervention still counted as open for {label}")

        rebirth_first = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
        require(
            rebirth_first["birthed"] == 0,
            f"rebirth happened without reconfirmation after landed for {label}",
        )
        rebirth_second = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
        require(
            rebirth_second["birthed"] == 1,
            f"rebirth did not happen after reconfirmation for {label}",
        )

print("PASS: bounded label set held, stale_failure rollout birthed exactly once per label::stale_failure, broker routing held, and scope did not widen")
PYEOF

echo "D434 PASS: autonomous exception birth V1 behavior held"
