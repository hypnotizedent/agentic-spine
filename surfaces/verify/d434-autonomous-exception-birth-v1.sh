#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRIFT_BIN="$ROOT/ops/plugins/core/lifecycle/bin/standing-program-drift-check"
LIB_DIR="$ROOT/ops/plugins/core/lifecycle/lib"
BIRTH_BIN="$ROOT/ops/plugins/core/lifecycle/bin/standing-program-intervention-birth"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

drift_json="$tmpdir/drift.json"
python3 "$DRIFT_BIN" --json >"$drift_json"

python3 - "$drift_json" "$LIB_DIR" "$BIRTH_BIN" "$REGISTRY" <<'PYEOF'
import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

import yaml

drift_path = Path(sys.argv[1])
lib_dir = Path(sys.argv[2])
birth_path = Path(sys.argv[3])
registry_path = Path(sys.argv[4])

sys.path.insert(0, str(lib_dir))
import delegation_broker as db
import standing_program_exception_v1 as spx


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


def registry_expected_labels() -> list[str]:
    registry = yaml.safe_load(registry_path.read_text(encoding="utf-8")) or {}
    labels = []
    for item in registry.get("labels") or []:
        if not isinstance(item, dict):
            continue
        if item.get("state") != "active" or item.get("birth_mode") != "standing_program":
            continue
        if not isinstance(item.get("proof_channel"), dict):
            continue
        label = str(item.get("label") or "").strip()
        if label:
            labels.append(label)
    return sorted(labels)


def expected_triggers(label: str) -> list[str]:
    entry = spx.registry_entry(label)
    proof_type = str((entry.get("proof_channel") or {}).get("type") or "")
    if entry.get("monitor", True) is False:
        return []
    if proof_type == "cycle_state":
        return ["threshold_breach", "stale_failure"]
    if proof_type == "heartbeat":
        return ["missed_heartbeat"]
    if proof_type in {"runtime_telemetry", "systemd_journal"}:
        return ["stale_failure"]
    return []


drift = read_json(drift_path)
labels = sorted(str(label) for label in (drift.get("labels") or []))
programs = [row for row in (drift.get("programs") or []) if isinstance(row, dict)]
by_label = {str(row.get("label") or ""): row for row in programs}
expected_labels = registry_expected_labels()

require(labels == expected_labels, f"standing-program drift labels must match registry proof-channel labels: got={labels} expected={expected_labels}")
require(sorted(spx.v1_labels()) == expected_labels, "compat label reader must return registry-derived labels")

for label in expected_labels:
    require(label in by_label, f"drift check missing registry label: {label}")
    require(
        by_label[label].get("enabled_trigger_types") == expected_triggers(label),
        f"enabled trigger types drifted for {label}: {by_label[label].get('enabled_trigger_types')} expected {expected_triggers(label)}",
    )

require("V1_ALLOWED_LABELS" not in Path(lib_dir / "standing_program_exception_v1.py").read_text(encoding="utf-8"), "hardcoded V1 label allowlist must remain subtracted")
require("STALE_FAILURE_ROLLOUT_LABELS" not in Path(lib_dir / "standing_program_exception_v1.py").read_text(encoding="utf-8"), "stale-failure rollout tuple must remain subtracted")


def stale_specimen(label: str) -> dict:
    entry = spx.registry_entry(label)
    trigger = {
        "enabled": True,
        "condition_met": True,
        "required_observations": 2,
        "evidence_surface": "verify.synthetic.standing_program",
        "evidence_ref": f"verify::{label}",
        "observed_status": "stale",
        "observed_counts": {
            "last_run_age_seconds": 200000,
            "stale_threshold_seconds": 90000,
        },
        "suggested_actions": ["verify synthetic standing-program intervention path"],
        "detail": "verify synthetic stale specimen",
    }
    return {
        "label": label,
        "birth_mode": "standing_program",
        "intended_node_role": str(entry.get("intended_node_role") or ""),
        "source_node": "verify",
        "proof_channel": dict(entry.get("proof_channel") or {}),
        "proof_channel_type": str((entry.get("proof_channel") or {}).get("type") or ""),
        "proof_channel_host": str((entry.get("proof_channel") or {}).get("host") or ""),
        "health": "stale",
        "detail": trigger["detail"],
        "last_evidence_at_utc": spx.utc_now(),
        "staleness_seconds": 200000,
        "stale_threshold_seconds": 90000,
        "evidence_surface": trigger["evidence_surface"],
        "evidence_ref": trigger["evidence_ref"],
        "observed_status": "stale",
        "observed_counts": dict(trigger["observed_counts"]),
        "enabled_trigger_types": ["stale_failure"],
        "active_trigger_types": ["stale_failure"],
        "drift_present": True,
        "trigger_evaluations": {"stale_failure": trigger},
    }


synthetic_label = next(
    label for label in expected_labels
    if "stale_failure" in expected_triggers(label)
)

with tempfile.TemporaryDirectory(prefix="standing-program-exception-birth-") as tmp_state:
    os.environ["SPINE_STATE"] = tmp_state
    Path(tmp_state, "interventions").mkdir(parents=True, exist_ok=True)

    loop_id = "LOOP-VERIFY-STANDING-PROGRAM-REGISTRY-TRUTH-20260430"
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
        "objective: verify registry-derived standing-program intervention path\n"
        "---\n",
        encoding="utf-8",
    )

    stale = stale_specimen(synthetic_label)
    first = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
    require(first["birthed"] == 0, "first stale observation birthed too early")
    second = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
    require(second["birthed"] == 1, "second stale observation did not birth")
    third = birth.process_programs([stale], state_root=tmp_state, dry_run=False)
    require(third["birthed"] == 0 and third["locked"] >= 1, "duplicate stale poll was not lock-suppressed")

    path, doc = spx.find_open_intervention(tmp_state, synthetic_label, "stale_failure")
    require(path is not None and doc is not None, "open intervention missing")
    require(str(doc.get("dedupe_key") or "") == f"{synthetic_label}::stale_failure", "dedupe key drifted")

    delegated = db.delegate(
        loop_id=loop_id,
        packet_id=str(doc.get("intervention_id")),
        state_root=tmp_state,
        objective=f"verify standing-program registry truth for {synthetic_label}",
        target_role="worker",
        delegator_terminal="VERIFY",
    )
    require(delegated.get("status") == "delegated", "delegation broker rejected synthetic intervention")
    require(delegated.get("packet_kind") == "intervention", "broker packet kind drifted")

print("PASS: standing-program drift uses registry proof-channel labels, trigger inference held, and intervention birth remains deduped")
PYEOF

echo "D434 PASS: autonomous standing-program exception birth behavior held"
