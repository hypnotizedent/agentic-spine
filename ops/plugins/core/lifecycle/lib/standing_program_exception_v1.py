from __future__ import annotations

import json
import os
import re
import subprocess
import time
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml


REPO_ROOT = Path(
    os.environ.get("SPINE_REPO")
    or Path(__file__).resolve().parents[5]
)
REGISTRY_PATH = REPO_ROOT / "ops" / "bindings" / "launchd.scheduler.registry.yaml"
WATCHER_HEALTH_BIN = REPO_ROOT / "ops" / "plugins" / "core" / "bin" / "watcher-health"
METABOLIZER_STATUS_BIN = (
    REPO_ROOT / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "operator-ingress-auto-metabolizer-status"
)
SCHEDULER_HEALTH_BIN = (
    REPO_ROOT / "ops" / "plugins" / "infra" / "host" / "bin" / "launchd-scheduler-health-status"
)

OPEN_DISPOSITIONS = frozenset({
    "active",  # legacy compatibility
    "pending",
    "acknowledged",
    "escalated",
})
TERMINAL_DISPOSITIONS = frozenset({
    "cancelled",
    "dismissed",
    "landed",
    "resolved",
    "superseded",
})
OBSERVATION_STATE_BASENAME = "AUTONOMOUS-EXCEPTION-BIRTH-PATH-V1-OBSERVATIONS.json"
TRANSIENT_HEALTH_STATES = frozenset({"unknown", "unreachable"})


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_utc(value: object) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    else:
        parsed = parsed.astimezone(timezone.utc)
    return parsed


def seconds_since(value: object) -> int | None:
    parsed = parse_utc(value)
    if parsed is None:
        return None
    return int((datetime.now(timezone.utc) - parsed).total_seconds())


def sanitize_label(label: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9.-]+", "-", str(label or "").strip())
    cleaned = re.sub(r"-{2,}", "-", cleaned).strip("-")
    return cleaned or "unknown"


def intervention_id(label: str, trigger_type: str) -> str:
    return f"INTERVENTION-{sanitize_label(label)}-{trigger_type}"


def intervention_filename(label: str, trigger_type: str) -> str:
    return f"{intervention_id(label, trigger_type)}.yaml"


def dedupe_key(label: str, trigger_type: str) -> str:
    return f"{label}::{trigger_type}"


def interventions_dir(state_root: str) -> Path:
    return Path(state_root) / "interventions"


def observation_state_path(state_root: str) -> Path:
    return Path(state_root) / "domain-state" / "spine" / OBSERVATION_STATE_BASENAME


def load_observation_state(state_root: str) -> dict[str, Any]:
    path = observation_state_path(state_root)
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def save_observation_state(state_root: str, data: dict[str, Any]) -> None:
    path = observation_state_path(state_root)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def atomic_write_yaml(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".yaml.tmp")
    tmp.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
    os.replace(tmp, path)


def read_yaml(path: Path) -> dict[str, Any] | None:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def is_open_disposition(disposition: object) -> bool:
    disp = str(disposition or "").strip().lower()
    if not disp:
        return False
    return disp in OPEN_DISPOSITIONS or disp not in TERMINAL_DISPOSITIONS


def list_intervention_files(state_root: str) -> list[Path]:
    idir = interventions_dir(state_root)
    if not idir.is_dir():
        return []
    paths = list(sorted(idir.glob("INTERVENTION-*.yaml")))
    # Keep legacy visibility compatible until old files age out.
    paths.extend(sorted(idir.glob("INT-*.yaml")))
    paths.extend(sorted(idir.glob("INTERVENTION-*.yml")))
    paths.extend(sorted(idir.glob("INT-*.yml")))
    return paths


def list_open_interventions(state_root: str) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for path in list_intervention_files(state_root):
        doc = read_yaml(path)
        if not doc:
            continue
        disposition = str(doc.get("disposition", "")).strip().lower()
        if not is_open_disposition(disposition):
            continue
        doc = dict(doc)
        doc["_path"] = str(path)
        doc["_source_label"] = str(doc.get("source_label") or doc.get("label") or "").strip()
        items.append(doc)
    return items


def find_open_intervention(
    state_root: str,
    label: str,
    trigger_type: str,
) -> tuple[Path, dict[str, Any]] | tuple[None, None]:
    target_key = dedupe_key(label, trigger_type)
    for path in list_intervention_files(state_root):
        doc = read_yaml(path)
        if not doc:
            continue
        if not is_open_disposition(doc.get("disposition")):
            continue
        doc_label = str(doc.get("source_label") or doc.get("label") or "").strip()
        doc_trigger = str(doc.get("trigger_type") or "").strip()
        doc_key = str(doc.get("dedupe_key") or "").strip()
        if doc_key == target_key or (doc_label == label and doc_trigger == trigger_type):
            return path, doc
    return None, None


def count_open_interventions(state_root: str, source_label: str | None = None) -> int:
    count = 0
    for doc in list_open_interventions(state_root):
        if source_label:
            doc_label = str(doc.get("_source_label") or "").strip()
            if doc_label != source_label:
                continue
        count += 1
    return count


def load_registry() -> dict[str, Any]:
    data = yaml.safe_load(REGISTRY_PATH.read_text(encoding="utf-8")) or {}
    return data if isinstance(data, dict) else {}


def registry_entry(label: str) -> dict[str, Any]:
    registry = load_registry()
    for entry in registry.get("labels", []) or []:
        if isinstance(entry, dict) and str(entry.get("label") or "").strip() == label:
            return entry
    raise KeyError(f"registry label not found: {label}")


def standing_program_entries() -> list[dict[str, Any]]:
    registry = load_registry()
    entries: list[dict[str, Any]] = []
    for entry in registry.get("labels", []) or []:
        if not isinstance(entry, dict):
            continue
        if entry.get("state") != "active" or entry.get("birth_mode") != "standing_program":
            continue
        proof = entry.get("proof_channel") if isinstance(entry.get("proof_channel"), dict) else {}
        if not proof:
            continue
        label = str(entry.get("label") or "").strip()
        if not label:
            continue
        entries.append(entry)
    return entries


def proof_channel_trigger_types(entry: dict[str, Any]) -> tuple[str, ...]:
    proof = entry.get("proof_channel") if isinstance(entry.get("proof_channel"), dict) else {}
    proof_type = str(proof.get("type") or "").strip()
    if proof_type == "cycle_state":
        return ("threshold_breach", "stale_failure")
    if proof_type == "heartbeat":
        return ("missed_heartbeat",)
    if proof_type in {"runtime_telemetry", "systemd_journal"}:
        return ("stale_failure",)
    return ()


def trigger_types_for_label(label: str) -> tuple[str, ...]:
    return proof_channel_trigger_types(registry_entry(label))


def v1_labels(labels: list[str] | None = None) -> list[str]:
    eligible = {str(entry.get("label") or "").strip() for entry in standing_program_entries()}
    if labels is None:
        return sorted(eligible)
    invalid = [label for label in labels if label not in eligible]
    if invalid:
        joined = ", ".join(sorted(invalid))
        raise ValueError(f"labels outside active standing-program proof set: {joined}")
    return labels


def _run_json(argv: list[str]) -> tuple[dict[str, Any], bool]:
    env = os.environ.copy()
    env.setdefault("SPINE_STATE", str(Path.home() / "code" / ".runtime" / "spine" / "state"))
    env.setdefault("SPINE_REPO", str(REPO_ROOT))
    try:
        proc = subprocess.run(
            argv,
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
            env=env,
        )
    except Exception as exc:
        return {"status": "error", "error": str(exc)}, False

    stdout = (proc.stdout or "").strip()
    stderr = (proc.stderr or "").strip()
    if stdout:
        try:
            data = json.loads(stdout)
            return data if isinstance(data, dict) else {"status": "error", "stdout": stdout}, proc.returncode == 0
        except Exception:
            pass

    return {
        "status": "error",
        "stdout": stdout,
        "stderr": stderr,
        "returncode": proc.returncode,
    }, False


@lru_cache(maxsize=1)
def _scheduler_health_payload() -> tuple[dict[str, Any], bool]:
    return _run_json(["python3", str(SCHEDULER_HEALTH_BIN), "--json"])


def _scheduler_health_row(label: str) -> tuple[dict[str, Any] | None, dict[str, Any], bool]:
    data, ok = _scheduler_health_payload()
    rows = ((data.get("data") or {}).get("rows") or []) if isinstance(data, dict) else []
    if not isinstance(rows, list):
        rows = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        if str(row.get("label") or "").strip() == label:
            return row, data, ok
    return None, data, ok


def _surface_result(
    *,
    label: str,
    entry: dict[str, Any],
    health: str,
    detail: str,
    last_evidence_at_utc: str | None,
    staleness_seconds: int | None,
    stale_threshold_seconds: int | None,
    evidence_surface: str,
    evidence_ref: str,
    observed_status: str,
    observed_counts: dict[str, Any],
    trigger_evaluations: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    enabled_trigger_types = [
        trigger_type
        for trigger_type, trigger in trigger_evaluations.items()
        if trigger.get("enabled")
    ]
    active_trigger_types = [
        trigger_type
        for trigger_type, trigger in trigger_evaluations.items()
        if trigger.get("enabled") and trigger.get("condition_met")
    ]
    return {
        "label": label,
        "birth_mode": str(entry.get("birth_mode") or ""),
        "intended_node_role": str(entry.get("intended_node_role") or ""),
        "source_node": str(
            entry.get("active_runtime_host")
            or (entry.get("proof_channel") or {}).get("host")
            or ""
        ),
        "proof_channel": dict(entry.get("proof_channel") or {}),
        "proof_channel_type": str((entry.get("proof_channel") or {}).get("type") or ""),
        "proof_channel_host": str((entry.get("proof_channel") or {}).get("host") or ""),
        "health": health,
        "detail": detail,
        "last_evidence_at_utc": last_evidence_at_utc,
        "staleness_seconds": staleness_seconds,
        "stale_threshold_seconds": stale_threshold_seconds,
        "evidence_surface": evidence_surface,
        "evidence_ref": evidence_ref,
        "observed_status": observed_status,
        "observed_counts": observed_counts,
        "enabled_trigger_types": enabled_trigger_types,
        "active_trigger_types": active_trigger_types,
        "drift_present": bool(active_trigger_types),
        "trigger_evaluations": trigger_evaluations,
    }


def _watcher_trigger_evaluations(
    entry: dict[str, Any],
    data: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    monitor_enabled = entry.get("monitor", True) is not False
    threshold = data.get("threshold", {}) if isinstance(data.get("threshold"), dict) else {}
    consecutive_failures = int(data.get("consecutive_failures", 0) or 0)
    intervention_threshold = int(threshold.get("failure_count_for_intervention", 0) or 0)
    last_run_at = data.get("last_run_at")
    last_run_age = seconds_since(last_run_at)
    stale_threshold = int((entry.get("proof_channel") or {}).get("stale_threshold_seconds", 0) or 0)
    trigger_counts = {
        "consecutive_failures": consecutive_failures,
        "threshold_failure_count_for_intervention": intervention_threshold,
        "last_run_age_seconds": last_run_age,
        "stale_threshold_seconds": stale_threshold,
    }
    return {
        "threshold_breach": {
            "enabled": monitor_enabled,
            "condition_met": bool(intervention_threshold and consecutive_failures >= intervention_threshold),
            "required_observations": 1,
            "evidence_surface": "watcher.health",
            "evidence_ref": str((entry.get("proof_channel") or {}).get("path") or ""),
            "observed_status": str(data.get("health") or "unknown"),
            "observed_counts": trigger_counts,
            "suggested_actions": [
                "Inspect watcher.health recent cycles.",
                "Check spine-watcher-alerting-probe-cycle timer/logs on the active watcher node.",
            ],
            "detail": f"consecutive_failures={consecutive_failures} threshold={intervention_threshold}",
        },
        "stale_failure": {
            "enabled": monitor_enabled,
            "condition_met": bool(last_run_age is not None and stale_threshold and last_run_age > stale_threshold),
            "required_observations": 2,
            "evidence_surface": "watcher.health",
            "evidence_ref": str((entry.get("proof_channel") or {}).get("path") or ""),
            "observed_status": "stale" if last_run_age is not None and stale_threshold and last_run_age > stale_threshold else str(data.get("health") or "unknown"),
            "observed_counts": {
                "last_run_age_seconds": last_run_age,
                "stale_threshold_seconds": stale_threshold,
                "last_run_status": str(data.get("last_run_status") or "unknown"),
            },
            "suggested_actions": [
                "Inspect watcher.health last-run age.",
                "Confirm watcher timer/service is still advancing on the active watcher node.",
            ],
            "detail": f"last_run_age_seconds={last_run_age} stale_threshold_seconds={stale_threshold}",
        },
    }


def evaluate_alerting_probe_cycle(entry: dict[str, Any]) -> dict[str, Any]:
    data, ok = _run_json([str(WATCHER_HEALTH_BIN), "--json"])
    proof_channel = entry.get("proof_channel") or {}
    evidence_ref = str(proof_channel.get("path") or "")

    if not ok or str(data.get("status") or "").strip() == "watcher_node_unreachable":
        detail = str(data.get("message") or data.get("error") or "watcher.health unavailable")
        return _surface_result(
            label=str(entry.get("label") or ""),
            entry=entry,
            health="unreachable",
            detail=detail,
            last_evidence_at_utc=None,
            staleness_seconds=None,
            stale_threshold_seconds=int(proof_channel.get("stale_threshold_seconds", 0) or 0) or None,
            evidence_surface="watcher.health",
            evidence_ref=evidence_ref,
            observed_status="unreachable",
            observed_counts={},
            trigger_evaluations=_watcher_trigger_evaluations(entry, {}),
        )

    last_run_at = str(data.get("last_run_at") or "").strip() or None
    last_run_age = seconds_since(last_run_at)
    stale_threshold = int(proof_channel.get("stale_threshold_seconds", 0) or 0) or None
    health = str(data.get("health") or "unknown").strip().lower()
    trigger_evaluations = _watcher_trigger_evaluations(entry, data)
    if trigger_evaluations["threshold_breach"]["condition_met"]:
        health = "failed"
    elif trigger_evaluations["stale_failure"]["condition_met"]:
        health = "stale"

    observed_counts = {
        "consecutive_failures": int(data.get("consecutive_failures", 0) or 0),
        "threshold_failure_count_for_intervention": int(((data.get("threshold") or {}).get("failure_count_for_intervention", 0)) or 0),
        "last_run_age_seconds": last_run_age,
        "stale_threshold_seconds": stale_threshold,
    }
    detail = str(
        data.get("last_run_status")
        or data.get("message")
        or "watcher.health evaluated"
    )
    return _surface_result(
        label=str(entry.get("label") or ""),
        entry=entry,
        health=health or "unknown",
        detail=detail,
        last_evidence_at_utc=last_run_at,
        staleness_seconds=last_run_age,
        stale_threshold_seconds=stale_threshold,
        evidence_surface="watcher.health",
        evidence_ref=evidence_ref,
        observed_status=str(data.get("last_run_status") or data.get("health") or "unknown"),
        observed_counts=observed_counts,
        trigger_evaluations=trigger_evaluations,
    )


def _metabolizer_trigger_evaluations(
    entry: dict[str, Any],
    data: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    monitor_enabled = entry.get("monitor", True) is not False
    proof_channel = entry.get("proof_channel") or {}
    heartbeat_state = str(data.get("heartbeat_state") or "unavailable").strip().lower()
    stale_threshold = int(data.get("stale_threshold_seconds", 0) or proof_channel.get("stale_threshold_seconds", 0) or 0)
    counts = {
        "heartbeat_age_seconds": data.get("heartbeat_age_seconds"),
        "stale_threshold_seconds": stale_threshold,
        "queue_pending": int(data.get("queue_pending", 0) or 0),
    }
    return {
        "missed_heartbeat": {
            "enabled": monitor_enabled,
            "condition_met": heartbeat_state in {"missing", "stale"},
            "required_observations": 2,
            "evidence_surface": "operator.ingress.auto_metabolize.status",
            "evidence_ref": str(proof_channel.get("path") or ""),
            "observed_status": heartbeat_state,
            "observed_counts": counts,
            "suggested_actions": [
                "Inspect operator.ingress.auto_metabolize.status.",
                "Check spine-operator-ingress-auto-metabolizer.service on ai-consolidation.",
            ],
            "detail": f"heartbeat_state={heartbeat_state} heartbeat_age_seconds={data.get('heartbeat_age_seconds')}",
        },
    }


def evaluate_operator_ingress_auto_metabolizer(entry: dict[str, Any]) -> dict[str, Any]:
    data, ok = _run_json(["python3", str(METABOLIZER_STATUS_BIN), "--json"])
    proof_channel = entry.get("proof_channel") or {}
    evidence_ref = str(proof_channel.get("path") or "")

    heartbeat_at = str(data.get("heartbeat_at") or "").strip() or None
    heartbeat_age = data.get("heartbeat_age_seconds")
    try:
        heartbeat_age = int(heartbeat_age) if heartbeat_age is not None else None
    except (TypeError, ValueError):
        heartbeat_age = None

    stale_threshold = int(data.get("stale_threshold_seconds", 0) or proof_channel.get("stale_threshold_seconds", 0) or 0) or None
    read_state = str(data.get("read_state") or ("ok" if ok else "unavailable")).strip().lower()
    heartbeat_state = str(data.get("heartbeat_state") or "unavailable").strip().lower()
    trigger_evaluations = _metabolizer_trigger_evaluations(entry, data)
    if read_state != "ok":
        health = "unreachable"
        detail = str(data.get("error") or "heartbeat evidence unavailable")
    elif heartbeat_state in {"missing", "stale"}:
        health = "stale"
        detail = str(data.get("health") or heartbeat_state)
    else:
        health = "healthy"
        detail = str(data.get("health") or "HEALTHY")

    return _surface_result(
        label=str(entry.get("label") or ""),
        entry=entry,
        health=health,
        detail=detail,
        last_evidence_at_utc=heartbeat_at,
        staleness_seconds=heartbeat_age,
        stale_threshold_seconds=stale_threshold,
        evidence_surface="operator.ingress.auto_metabolize.status",
        evidence_ref=evidence_ref,
        observed_status=heartbeat_state if read_state == "ok" else read_state,
        observed_counts={
            "heartbeat_age_seconds": heartbeat_age,
            "stale_threshold_seconds": stale_threshold,
            "queue_pending": int(data.get("queue_pending", 0) or 0),
        },
        trigger_evaluations=trigger_evaluations,
    )


def _heartbeat_file_trigger_evaluations(
    entry: dict[str, Any],
    *,
    heartbeat_age: int | None,
    stale_threshold: int | None,
    read_state: str,
) -> dict[str, dict[str, Any]]:
    monitor_enabled = entry.get("monitor", True) is not False
    condition_met = read_state != "ok" or (
        heartbeat_age is not None and stale_threshold is not None and heartbeat_age > stale_threshold
    )
    return {
        "missed_heartbeat": {
            "enabled": monitor_enabled,
            "condition_met": condition_met,
            "required_observations": 2,
            "evidence_surface": "standing_program.proof_channel.heartbeat",
            "evidence_ref": str((entry.get("proof_channel") or {}).get("path") or ""),
            "observed_status": "stale" if condition_met else "fresh",
            "observed_counts": {
                "heartbeat_age_seconds": heartbeat_age,
                "stale_threshold_seconds": stale_threshold,
            },
            "suggested_actions": [
                "Inspect the declared proof_channel heartbeat file.",
                "Restore the standing program that writes this heartbeat.",
            ],
            "detail": f"read_state={read_state} heartbeat_age_seconds={heartbeat_age}",
        },
    }


def _local_heartbeat_candidate(path_text: str) -> Path:
    path = Path(path_text)
    if path.is_file():
        return path
    marker = "/.runtime/spine/state/"
    if marker in path_text:
        tail = path_text.split(marker, 1)[1]
        state_root = Path(os.environ.get("SPINE_STATE", str(Path.home() / "code" / ".runtime" / "spine" / "state")))
        return state_root / tail
    return path


def evaluate_file_heartbeat_label(entry: dict[str, Any]) -> dict[str, Any]:
    label = str(entry.get("label") or "")
    proof_channel = entry.get("proof_channel") or {}
    path_text = str(proof_channel.get("path") or "")
    stale_threshold = int(proof_channel.get("stale_threshold_seconds", 0) or 0) or None
    path = _local_heartbeat_candidate(path_text)
    heartbeat_at = None
    read_state = "missing"
    detail = "heartbeat file missing"
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            data = {}
            read_state = "error"
            detail = f"heartbeat json unreadable: {exc}"
        if isinstance(data, dict):
            heartbeat_at = str(
                data.get("heartbeat_at")
                or data.get("updated_at")
                or data.get("recorded_at")
                or data.get("last_run_at")
                or data.get("timestamp")
                or ""
            ).strip() or None
            read_state = "ok" if heartbeat_at else "missing_timestamp"
            detail = str(data.get("health") or data.get("status") or read_state)
    heartbeat_age = seconds_since(heartbeat_at)
    trigger_evaluations = _heartbeat_file_trigger_evaluations(
        entry,
        heartbeat_age=heartbeat_age,
        stale_threshold=stale_threshold,
        read_state=read_state,
    )
    if read_state != "ok":
        health = "unknown"
    elif heartbeat_age is not None and stale_threshold is not None and heartbeat_age > stale_threshold:
        health = "stale"
    else:
        health = "healthy"
    return _surface_result(
        label=label,
        entry=entry,
        health=health,
        detail=detail,
        last_evidence_at_utc=heartbeat_at,
        staleness_seconds=heartbeat_age,
        stale_threshold_seconds=stale_threshold,
        evidence_surface="standing_program.proof_channel.heartbeat",
        evidence_ref=path_text,
        observed_status=read_state,
        observed_counts={
            "heartbeat_age_seconds": heartbeat_age,
            "stale_threshold_seconds": stale_threshold,
        },
        trigger_evaluations=trigger_evaluations,
    )


def _scheduler_evidence_ref(entry: dict[str, Any], label: str) -> str:
    proof_channel = entry.get("proof_channel") or {}
    path = str(proof_channel.get("path") or "").strip()
    return f"{path}::{label}" if path else label


def _scheduler_stale_failure_trigger(
    entry: dict[str, Any],
    row: dict[str, Any] | None,
) -> dict[str, dict[str, Any]]:
    status = str((row or {}).get("status") or "unknown").strip().lower()
    last_run_age = (row or {}).get("age_seconds")
    try:
        last_run_age = int(last_run_age) if last_run_age is not None else None
    except (TypeError, ValueError):
        last_run_age = None

    stale_threshold = (row or {}).get("stale_threshold_seconds")
    try:
        stale_threshold = int(stale_threshold) if stale_threshold is not None else None
    except (TypeError, ValueError):
        stale_threshold = None

    cadence_seconds = (row or {}).get("cadence_seconds")
    try:
        cadence_seconds = int(cadence_seconds) if cadence_seconds is not None else None
    except (TypeError, ValueError):
        cadence_seconds = None

    last_exit_code = (row or {}).get("last_exit_code")
    try:
        last_exit_code = int(last_exit_code) if last_exit_code is not None else None
    except (TypeError, ValueError):
        last_exit_code = None

    required_observations = 1 if status == "failed" else 2
    label = str(entry.get("label") or "")
    monitor_enabled = entry.get("monitor", True) is not False
    return {
        "stale_failure": {
            "enabled": monitor_enabled,
            "condition_met": status in {"stale", "failed"},
            "required_observations": required_observations,
            "evidence_surface": "host.launchd.scheduler.health.status",
            "evidence_ref": _scheduler_evidence_ref(entry, label),
            "observed_status": status,
            "observed_counts": {
                "scheduler_status": status,
                "last_run_age_seconds": last_run_age,
                "stale_threshold_seconds": stale_threshold,
                "cadence_seconds": cadence_seconds,
                "last_exit_code": last_exit_code,
            },
            "suggested_actions": [
                "Inspect host.launchd.scheduler.health.status for the label row.",
                "Restore scheduled cadence execution for the workload on ai-consolidation.",
            ],
            "detail": (
                f"scheduler_status={status} "
                f"last_run_age_seconds={last_run_age} "
                f"stale_threshold_seconds={stale_threshold}"
            ),
        },
    }


def evaluate_scheduler_stale_failure_label(entry: dict[str, Any]) -> dict[str, Any]:
    label = str(entry.get("label") or "")
    proof_channel = entry.get("proof_channel") or {}
    evidence_ref = _scheduler_evidence_ref(entry, label)
    row, data, ok = _scheduler_health_row(label)
    trigger_evaluations = _scheduler_stale_failure_trigger(entry, row)

    if not ok:
        detail = str(data.get("error") or data.get("stderr") or "scheduler health unavailable")
        return _surface_result(
            label=label,
            entry=entry,
            health="unreachable",
            detail=detail,
            last_evidence_at_utc=None,
            staleness_seconds=None,
            stale_threshold_seconds=None,
            evidence_surface="host.launchd.scheduler.health.status",
            evidence_ref=evidence_ref,
            observed_status="unreachable",
            observed_counts={},
            trigger_evaluations=trigger_evaluations,
        )

    if row is None:
        return _surface_result(
            label=label,
            entry=entry,
            health="unknown",
            detail="scheduler health row missing",
            last_evidence_at_utc=None,
            staleness_seconds=None,
            stale_threshold_seconds=int(proof_channel.get("stale_threshold_seconds", 0) or 0) or None,
            evidence_surface="host.launchd.scheduler.health.status",
            evidence_ref=evidence_ref,
            observed_status="missing_row",
            observed_counts={},
            trigger_evaluations=trigger_evaluations,
        )

    status = str(row.get("status") or "unknown").strip().lower()
    health = {
        "ok": "healthy",
        "allowed_nonzero": "healthy",
        "exempt": "healthy",
        "stale": "stale",
        "failed": "failed",
        "unknown": "unknown",
    }.get(status, "unknown")
    last_run_at = str(row.get("last_run_at") or "").strip() or None

    last_run_age = row.get("age_seconds")
    try:
        last_run_age = int(last_run_age) if last_run_age is not None else None
    except (TypeError, ValueError):
        last_run_age = None

    stale_threshold = row.get("stale_threshold_seconds")
    try:
        stale_threshold = int(stale_threshold) if stale_threshold is not None else None
    except (TypeError, ValueError):
        stale_threshold = None

    cadence_seconds = row.get("cadence_seconds")
    try:
        cadence_seconds = int(cadence_seconds) if cadence_seconds is not None else None
    except (TypeError, ValueError):
        cadence_seconds = None

    last_exit_code = row.get("last_exit_code")
    try:
        last_exit_code = int(last_exit_code) if last_exit_code is not None else None
    except (TypeError, ValueError):
        last_exit_code = None

    detail = (
        f"scheduler_status={status} "
        f"last_run_age_seconds={last_run_age} "
        f"stale_threshold_seconds={stale_threshold}"
    )
    return _surface_result(
        label=label,
        entry=entry,
        health=health,
        detail=detail,
        last_evidence_at_utc=last_run_at,
        staleness_seconds=last_run_age,
        stale_threshold_seconds=stale_threshold,
        evidence_surface="host.launchd.scheduler.health.status",
        evidence_ref=evidence_ref,
        observed_status=status,
        observed_counts={
            "scheduler_status": status,
            "last_run_age_seconds": last_run_age,
            "stale_threshold_seconds": stale_threshold,
            "cadence_seconds": cadence_seconds,
            "last_exit_code": last_exit_code,
        },
        trigger_evaluations=trigger_evaluations,
    )


def evaluate_label(label: str) -> dict[str, Any]:
    entry = registry_entry(label)
    proof = entry.get("proof_channel") if isinstance(entry.get("proof_channel"), dict) else {}
    proof_type = str(proof.get("type") or "").strip()
    if label == "com.ronny.alerting-probe-cycle":
        return evaluate_alerting_probe_cycle(entry)
    if label == "com.ronny.operator-ingress-auto-metabolizer":
        return evaluate_operator_ingress_auto_metabolizer(entry)
    if proof_type in {"runtime_telemetry", "systemd_journal"}:
        return evaluate_scheduler_stale_failure_label(entry)
    if proof_type == "heartbeat":
        return evaluate_file_heartbeat_label(entry)
    raise ValueError(f"unsupported standing-program proof_channel.type for {label}: {proof_type}")


def evaluate_labels(labels: list[str] | None = None) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for label in v1_labels(labels):
        result = evaluate_label(label)
        # Remote proof readers can occasionally miss one poll due to a transient
        # SSH/readback wobble. Retry once before surfacing a degraded operator
        # read model.
        if str(result.get("health") or "").strip().lower() in TRANSIENT_HEALTH_STATES:
            time.sleep(0.2)
            retried = evaluate_label(label)
            if str(retried.get("health") or "").strip().lower() not in TRANSIENT_HEALTH_STATES:
                result = retried
        results.append(result)
    return results


def build_exception_specimen_states(
    evaluations: list[dict[str, Any]],
    state_root: str,
) -> list[dict[str, Any]]:
    by_label: dict[str, list[dict[str, Any]]] = {}
    for doc in list_open_interventions(state_root):
        label = str(doc.get("_source_label") or "").strip()
        if not label:
            continue
        by_label.setdefault(label, []).append(doc)

    items: list[dict[str, Any]] = []
    for evaluation in evaluations:
        label = str(evaluation.get("label") or "").strip()
        active_trigger_types = list(evaluation.get("active_trigger_types") or [])
        interventions = by_label.get(label, [])
        primary = interventions[0] if interventions else {}
        birth_mode = str(evaluation.get("birth_mode") or "")

        if birth_mode == "human_session_only":
            operator_state = "human_born_only"
        elif interventions:
            operator_state = "auto_birthed_intervention_active"
        elif active_trigger_types:
            operator_state = "standing_stale_or_degraded"
        else:
            operator_state = "standing_healthy"

        items.append({
            "label": label,
            "operator_state": operator_state,
            "drift_present": bool(active_trigger_types),
            "active_trigger_types": active_trigger_types,
            "enabled_trigger_types": list(evaluation.get("enabled_trigger_types") or []),
            "intervention_active": bool(interventions),
            "intervention_id": str(primary.get("intervention_id") or ""),
            "intervention_trigger_type": str(primary.get("trigger_type") or ""),
            "intervention_disposition": str(primary.get("disposition") or ""),
            "delegation_state": str(primary.get("delegation_state") or "not_delegated"),
            "escalation_state": str(primary.get("escalation_state") or "packet_only"),
            "manual_birth_not_needed": bool(interventions),
            "governable": bool(interventions),
            "detail": str(evaluation.get("detail") or ""),
            "evidence_surface": str(evaluation.get("evidence_surface") or ""),
            "evidence_ref": str(evaluation.get("evidence_ref") or ""),
            "health": str(evaluation.get("health") or "unknown"),
            "observed_counts": dict(evaluation.get("observed_counts") or {}),
        })
    return items
