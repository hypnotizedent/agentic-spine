#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import signal
import subprocess
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[5]
MAILROOM_RUNTIME_CONTRACT = ROOT / "ops/bindings/mailroom.runtime.contract.yaml"
DEFAULT_QUEUE_CONTRACT = ROOT / "ops/bindings/communications.alerts.queue.contract.yaml"
DEFAULT_DELIVERY_LOG_BIN = ROOT / "ops/plugins/domains/communications/bin/communications-delivery-log"
DEFAULT_DISPATCHER_STATUS_BIN = ROOT / "ops/plugins/domains/communications/bin/communications-alerts-dispatcher-status"


def load_yaml(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        with path.open("r", encoding="utf-8") as fh:
            docs = list(yaml.safe_load_all(fh))
    except Exception:
        return default
    if not docs:
        return default
    if len(docs) == 1:
        data = docs[0]
    else:
        merged: dict[str, Any] = {}
        for doc in docs:
            if isinstance(doc, dict):
                merged.update(doc)
        data = merged if merged else docs[-1]
    return default if data is None else data


def resolve_runtime_paths() -> dict[str, Path]:
    contract = load_yaml(MAILROOM_RUNTIME_CONTRACT, {})
    runtime_active = bool(contract.get("active"))
    runtime_root = str(contract.get("runtime_root", "")).strip()
    mailroom_root = str(contract.get("mailroom_root", "")).strip()

    outbox = os.environ.get("SPINE_OUTBOX")
    state = os.environ.get("SPINE_STATE")
    logs = os.environ.get("SPINE_LOGS")

    if runtime_active and runtime_root:
        outbox = outbox or f"{runtime_root}/outbox"
        state = state or f"{runtime_root}/state"
        logs = logs or f"{runtime_root}/logs"
    elif mailroom_root:
        outbox = outbox or f"{mailroom_root}/outbox"

    outbox = outbox or str(ROOT / "mailroom/outbox")
    state = state or str(ROOT / "mailroom/state")
    logs = logs or str(ROOT / "mailroom/logs")
    return {
        "outbox": Path(outbox),
        "state": Path(state),
        "logs": Path(logs),
    }


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def expand_spine_outbox(value: str, outbox: Path) -> str:
    raw = str(value or "").strip()
    if not raw:
        return raw
    return raw.replace("$SPINE_OUTBOX", str(outbox))


def _to_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    text = str(value).strip().lower()
    if text in {"true", "1", "yes", "on"}:
        return True
    if text in {"false", "0", "no", "off"}:
        return False
    return default


def _to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return default


def iso_to_epoch(raw: str) -> int | None:
    text = str(raw or "").strip()
    if not text:
        return None
    try:
        parsed = dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return int(parsed.timestamp())


def _run_json_command(
    cmd: list[str],
    *,
    env: dict[str, str] | None = None,
    cwd: Path | None = None,
    timeout: int = 15,
) -> tuple[int, dict[str, Any]]:
    proc = subprocess.Popen(
        cmd,
        cwd=str(cwd or ROOT),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            stdout, stderr = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, stderr = proc.communicate()
        return 124, {
            "status": "error",
            "error": {
                "message": f"command timed out after {timeout}s",
                "command": cmd,
            },
            "stdout": stdout,
            "stderr": stderr,
        }

    text = (stdout or "").strip() or (stderr or "").strip()
    if not text:
        return proc.returncode, {}
    try:
        return proc.returncode, json.loads(text)
    except json.JSONDecodeError:
        return proc.returncode, {
            "status": "error",
            "error": {
                "message": text,
                "command": cmd,
            },
        }


def queue_contract_path() -> Path:
    raw = os.environ.get("COMMUNICATIONS_ALERTS_QUEUE_CONTRACT", str(DEFAULT_QUEUE_CONTRACT))
    path = Path(raw)
    if not path.is_absolute():
        path = (ROOT / raw).resolve()
    return path


def _resolve_queue_paths(contract_path: Path) -> dict[str, Path]:
    runtime = resolve_runtime_paths()
    outbox = runtime["outbox"]
    contract = load_yaml(contract_path, {})

    intent_dir = outbox / "alerts/email-intents"
    dead_letter_raw = ""
    if isinstance(contract, dict):
        retry_policy = contract.get("retry_policy", {})
        if isinstance(retry_policy, dict):
            dead_letter_raw = str(retry_policy.get("dead_letter_dir", "")).strip()
    if not dead_letter_raw:
        dead_letter_raw = "$SPINE_OUTBOX/alerts/email-intents-dead-letter"
    dead_letter_dir = Path(expand_spine_outbox(dead_letter_raw, outbox))
    return {
        "outbox": outbox,
        "intent_dir": intent_dir,
        "dead_letter_dir": dead_letter_dir,
    }


def collect_queue_status(*, limit: int = 25, contract_path: Path | None = None) -> dict[str, Any]:
    contract_path = contract_path or queue_contract_path()
    contract = load_yaml(contract_path, {})
    paths = _resolve_queue_paths(contract_path)
    intent_dir = paths["intent_dir"]
    dead_letter_dir = paths["dead_letter_dir"]
    retry_enabled = True
    if isinstance(contract, dict):
        retry_policy = contract.get("retry_policy", {})
        if isinstance(retry_policy, dict):
            retry_enabled = _to_bool(retry_policy.get("enabled", True), True)

    now_epoch = int(dt.datetime.now(dt.timezone.utc).timestamp())
    pending_count = 0
    pending_ready_count = 0
    retry_scheduled_count = 0
    sent_count = 0
    failed_count = 0
    dead_letter_count = 0
    oldest_pending_epoch: int | None = None
    newest_pending_epoch: int | None = None
    top_pending: list[dict[str, Any]] = []

    if intent_dir.exists():
        for path in sorted(intent_dir.rglob("*.yaml")):
            if not path.is_file():
                continue
            payload = load_yaml(path, {})
            if not isinstance(payload, dict):
                continue

            flush_status = str(payload.get("flush_status", "pending") or "pending").strip()
            created_at = str(payload.get("created_at", "")).strip()
            attempts = _to_int(payload.get("attempts", 0), 0)
            next_retry_at = str(payload.get("next_retry_at", "")).strip()
            last_error = str(payload.get("last_error", "")).strip()
            file_epoch = iso_to_epoch(created_at)

            ready_now = True
            if flush_status == "sent":
                sent_count += 1
                continue
            if flush_status == "dead-letter":
                dead_letter_count += 1
                continue
            if flush_status == "retry_scheduled":
                retry_scheduled_count += 1
                if retry_enabled and next_retry_at:
                    next_retry_epoch = iso_to_epoch(next_retry_at)
                    ready_now = next_retry_epoch is None or next_retry_epoch <= now_epoch
                else:
                    ready_now = True
            elif flush_status == "failed":
                failed_count += 1

            pending_count += 1
            if ready_now:
                pending_ready_count += 1

            if file_epoch is not None:
                oldest_pending_epoch = file_epoch if oldest_pending_epoch is None else min(oldest_pending_epoch, file_epoch)
                newest_pending_epoch = file_epoch if newest_pending_epoch is None else max(newest_pending_epoch, file_epoch)

            if len(top_pending) < max(0, int(limit)):
                top_pending.append(
                    {
                        "intent_id": str(payload.get("intent_id", "")).strip(),
                        "domain_id": str(payload.get("domain_id", "")).strip(),
                        "severity": str(payload.get("severity", "")).strip(),
                        "created_at": created_at,
                        "recipient": str(payload.get("suggested_recipient", "")).strip(),
                        "flush_status": flush_status,
                        "attempts": attempts,
                        "next_retry_at": next_retry_at,
                        "ready_now": ready_now,
                        "last_error": last_error,
                    }
                )

    if dead_letter_dir.exists():
        dead_letter_count += sum(1 for path in dead_letter_dir.rglob("*.yaml") if path.is_file())

    oldest_pending_age = max(0, now_epoch - oldest_pending_epoch) if oldest_pending_epoch is not None else 0
    newest_pending_age = max(0, now_epoch - newest_pending_epoch) if newest_pending_epoch is not None else 0

    return {
        "capability": "communications.alerts.queue.status",
        "status": "ok",
        "generated_at": utc_now(),
        "data": {
            "pending_count": pending_count,
            "pending_ready_count": pending_ready_count,
            "retry_scheduled_count": retry_scheduled_count,
            "sent_count": sent_count,
            "failed_count": failed_count,
            "dead_letter_count": dead_letter_count,
            "oldest_pending_age_seconds": oldest_pending_age,
            "newest_pending_age_seconds": newest_pending_age,
            "top_pending": top_pending,
        },
    }


def collect_dispatcher_status(*, contract_path: Path | None = None) -> dict[str, Any]:
    contract_path = contract_path or queue_contract_path()
    contract = load_yaml(contract_path, {})
    dispatcher_enabled = True
    if isinstance(contract, dict):
        dispatcher = contract.get("dispatcher", {})
        if isinstance(dispatcher, dict):
            dispatcher_enabled = _to_bool(dispatcher.get("enabled", True), True)
    if not dispatcher_enabled:
        return {"enabled": False, "running": False, "status": "disabled"}

    script = Path(os.environ.get("COMMUNICATIONS_ALERTS_DISPATCHER_STATUS_BIN", str(DEFAULT_DISPATCHER_STATUS_BIN)))
    if not script.is_absolute():
        script = (ROOT / script).resolve()
    if not script.exists():
        return {"enabled": True, "running": False, "status": "unknown"}

    env = os.environ.copy()
    env["COMMUNICATIONS_ALERTS_QUEUE_CONTRACT"] = str(contract_path)
    rc, payload = _run_json_command([str(script), "--json"], env=env, timeout=10)
    data = payload.get("data", {}) if isinstance(payload, dict) else {}
    return {
        "enabled": True,
        "running": bool(data.get("running", False)),
        "status": str(payload.get("status", "unknown" if rc else "ok")),
    }


def collect_queue_slo_status(
    *,
    contract_path: Path | None = None,
    queue_status: dict[str, Any] | None = None,
    dispatcher_status: dict[str, Any] | None = None,
) -> dict[str, Any]:
    contract_path = contract_path or queue_contract_path()
    contract = load_yaml(contract_path, {})
    queue_status = queue_status or collect_queue_status(contract_path=contract_path)
    dispatcher_status = dispatcher_status or collect_dispatcher_status(contract_path=contract_path)
    data = queue_status.get("data", {})

    slo = contract.get("slo", {}) if isinstance(contract, dict) else {}
    recommended_actions = contract.get("recommended_actions", {}) if isinstance(contract, dict) else {}
    dispatcher_cfg = contract.get("dispatcher", {}) if isinstance(contract, dict) else {}

    warn_age = _to_int(slo.get("warn_age_seconds", 3600), 3600)
    incident_age = _to_int(slo.get("incident_age_seconds", 14400), 14400)
    max_pending_warn = _to_int(slo.get("max_pending_warn", 50), 50)
    max_pending_incident = _to_int(slo.get("max_pending_incident", 200), 200)
    dead_letter_warn = _to_int(slo.get("dead_letter_warn", 1), 1)
    dead_letter_incident = _to_int(slo.get("dead_letter_incident", 10), 10)

    dispatcher_enabled = _to_bool(dispatcher_cfg.get("enabled", dispatcher_status.get("enabled", True)), True)
    dispatcher_running = bool(dispatcher_status.get("running", False))
    dispatcher_state = str(dispatcher_status.get("status", "unknown"))

    pending_count = _to_int(data.get("pending_count", 0), 0)
    pending_ready_count = _to_int(data.get("pending_ready_count", 0), 0)
    oldest_age = _to_int(data.get("oldest_pending_age_seconds", 0), 0)
    dead_letter_count = _to_int(data.get("dead_letter_count", 0), 0)

    slo_status = "ok"
    reasons: list[str] = []

    if oldest_age >= incident_age:
        slo_status = "incident"
        reasons.append(f"oldest_pending_age {oldest_age}s >= incident_threshold {incident_age}s")
    elif oldest_age >= warn_age:
        slo_status = "warn"
        reasons.append(f"oldest_pending_age {oldest_age}s >= warn_threshold {warn_age}s")

    if pending_count >= max_pending_incident:
        slo_status = "incident"
        reasons.append(f"pending_count {pending_count} >= incident_threshold {max_pending_incident}")
    elif pending_count >= max_pending_warn and slo_status != "incident":
        slo_status = "warn"
        reasons.append(f"pending_count {pending_count} >= warn_threshold {max_pending_warn}")

    if dead_letter_count >= dead_letter_incident:
        slo_status = "incident"
        reasons.append(f"dead_letter_count {dead_letter_count} >= incident_threshold {dead_letter_incident}")
    elif dead_letter_count >= dead_letter_warn and slo_status != "incident":
        slo_status = "warn"
        reasons.append(f"dead_letter_count {dead_letter_count} >= warn_threshold {dead_letter_warn}")

    if dispatcher_enabled and pending_count > 0 and not dispatcher_running:
        if slo_status == "ok":
            slo_status = "warn"
        reasons.append("dispatcher_not_running_with_pending_queue")

    flush_command = str(recommended_actions.get("flush_command", "")).strip()
    dispatcher_start_command = str(recommended_actions.get("dispatcher_start_command", "")).strip()
    replay_dead_letter_command = str(recommended_actions.get("replay_dead_letter_command", "")).strip()

    recommended_action = ""
    if pending_count > 0:
        if dispatcher_enabled:
            if not dispatcher_running and dispatcher_start_command:
                recommended_action = dispatcher_start_command
        else:
            recommended_action = flush_command
    elif dead_letter_count > 0:
        recommended_action = replay_dead_letter_command

    escalation_recommended = slo_status == "incident"
    escalation_reason = "SLO status is incident — governed escalation available" if escalation_recommended else ""
    escalation_fingerprint = ""
    if escalation_recommended:
        age_bucket = (oldest_age // 3600) * 3600
        pending_bucket = (pending_count // 50) * 50
        dead_letter_bucket = (dead_letter_count // 10) * 10
        fp_input = f"{slo_status}|{age_bucket}|{pending_bucket}|{dead_letter_bucket}"
        escalation_fingerprint = hashlib.md5(fp_input.encode("utf-8")).hexdigest()

    return {
        "capability": "communications.alerts.queue.slo.status",
        "status": slo_status,
        "generated_at": utc_now(),
        "data": {
            "pending_count": pending_count,
            "pending_ready_count": pending_ready_count,
            "dead_letter_count": dead_letter_count,
            "oldest_pending_age_seconds": oldest_age,
            "thresholds": {
                "warn_age_seconds": warn_age,
                "incident_age_seconds": incident_age,
                "max_pending_warn": max_pending_warn,
                "max_pending_incident": max_pending_incident,
                "dead_letter_warn": dead_letter_warn,
                "dead_letter_incident": dead_letter_incident,
            },
            "dispatcher": {
                "enabled": dispatcher_enabled,
                "running": dispatcher_running,
                "status": dispatcher_state,
            },
            "reasons": reasons,
            "recommended_action": recommended_action,
            "escalation_recommended": escalation_recommended,
            "escalation_reason": escalation_reason,
            "escalation_fingerprint": escalation_fingerprint,
            "suggested_command": 'echo "yes" | ./bin/ops cap run communications.alerts.queue.escalate --execute',
        },
    }


def collect_runtime_status(
    *,
    contract_path: Path | None = None,
    queue_limit: int = 25,
    delivery_limit: int = 20,
) -> dict[str, Any]:
    contract_path = contract_path or queue_contract_path()
    queue_status = collect_queue_status(limit=queue_limit, contract_path=contract_path)
    dispatcher_status = collect_dispatcher_status(contract_path=contract_path)
    slo_status = collect_queue_slo_status(
        contract_path=contract_path,
        queue_status=queue_status,
        dispatcher_status=dispatcher_status,
    )

    queue_data = queue_status.get("data", {})
    slo_data = slo_status.get("data", {})
    runtime = resolve_runtime_paths()
    escalation_dir = runtime["outbox"] / "alerts/communications/escalations"

    last_escalation_at = ""
    last_escalation_fingerprint = ""
    pending_escalation_task_count = 0
    if escalation_dir.exists():
        for path in sorted(escalation_dir.rglob("*.yaml"), reverse=True):
            if not path.is_file():
                continue
            if ".proposal-skeleton" in path.name:
                continue
            payload = load_yaml(path, {})
            if isinstance(payload, dict) and str(payload.get("status", "unknown")).strip() == "open":
                pending_escalation_task_count += 1
        latest = next((path for path in sorted(escalation_dir.glob("ESCALATION-*.yaml"), reverse=True) if path.is_file()), None)
        if latest is not None:
            payload = load_yaml(latest, {})
            if isinstance(payload, dict):
                last_escalation_at = str(payload.get("created_at", "")).strip()
                last_escalation_fingerprint = str(payload.get("fingerprint", "")).strip()

    delivery_recent_count = 0
    delivery_recent_failed = 0
    delivery_bin = Path(os.environ.get("COMMUNICATIONS_DELIVERY_LOG_BIN", str(DEFAULT_DELIVERY_LOG_BIN)))
    if not delivery_bin.is_absolute():
        delivery_bin = (ROOT / delivery_bin).resolve()
    if delivery_bin.exists():
        rc, payload = _run_json_command([str(delivery_bin), "--limit", str(max(1, delivery_limit)), "--json"], timeout=15)
        data = payload.get("data", {}) if isinstance(payload, dict) else {}
        records = data.get("records", []) if isinstance(data, dict) else []
        delivery_recent_count = _to_int(data.get("count", len(records)), len(records))
        delivery_recent_failed = sum(1 for row in records if isinstance(row, dict) and str(row.get("status", "")).strip() == "failed")
        if rc == 124:
            delivery_recent_count = 0
            delivery_recent_failed = 0

    rollup_status = str(slo_status.get("status", "unknown"))
    if rollup_status == "unknown":
        rollup_status = "ok"
    oneliner = (
        f"CommsQueue: {slo_data.get('slo_status', rollup_status)} "
        f"(pending={queue_data.get('pending_count', 0)} "
        f"oldest={queue_data.get('oldest_pending_age_seconds', 0)}s "
        f"escalations={pending_escalation_task_count})"
    )

    return {
        "capability": "communications.alerts.runtime.status",
        "status": rollup_status,
        "generated_at": utc_now(),
        "data": {
            "queue_pending_count": _to_int(queue_data.get("pending_count", 0), 0),
            "queue_oldest_age_seconds": _to_int(queue_data.get("oldest_pending_age_seconds", 0), 0),
            "queue_sent_count": _to_int(queue_data.get("sent_count", 0), 0),
            "queue_failed_count": _to_int(queue_data.get("failed_count", 0), 0),
            "slo_status": str(slo_status.get("status", "unknown")),
            "escalation_recommended": bool(slo_data.get("escalation_recommended", False)),
            "last_escalation_at": last_escalation_at,
            "last_escalation_fingerprint": last_escalation_fingerprint,
            "pending_escalation_task_count": pending_escalation_task_count,
            "recommended_action": str(slo_data.get("recommended_action", "")),
            "slo_reasons": list(slo_data.get("reasons", [])) if isinstance(slo_data.get("reasons", []), list) else [],
            "delivery_recent_count": delivery_recent_count,
            "delivery_recent_failed": delivery_recent_failed,
            "oneliner": oneliner,
        },
    }
