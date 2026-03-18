from __future__ import annotations

import base64
import fcntl
import hashlib
import json
import os
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_SPINE_ROOT = SCRIPT_DIR.parents[4]
DEFAULT_SPINE_STATE = Path.home() / "code" / ".runtime" / "spine" / "state"


def _load_contract() -> dict[str, Any]:
    spine_root = Path(os.environ.get("SPINE_ROOT", DEFAULT_SPINE_ROOT)).expanduser().resolve()
    contract_path = spine_root / "ops/bindings/mint.customer.interaction.record.contract.yaml"
    if not contract_path.exists():
        return {}
    try:
        return yaml.safe_load(contract_path.read_text()) or {}
    except Exception:
        return {}


def _resolve_state_root() -> Path:
    spine_state = os.environ.get("SPINE_STATE")
    if spine_state:
        return Path(spine_state).expanduser().resolve()
    return DEFAULT_SPINE_STATE


def _expand_storage_path(template: str) -> Path:
    state_root = _resolve_state_root()
    expanded = template.replace("$SPINE_STATE", str(state_root))
    return Path(expanded).expanduser().resolve()


def get_interaction_storage_paths() -> dict[str, Path]:
    contract = _load_contract()
    storage = contract.get("storage", {})
    return {
        "records_root": _expand_storage_path(storage.get("records_root", "$SPINE_STATE/mint/customer-interactions/records")),
        "index_file": _expand_storage_path(storage.get("index_file", "$SPINE_STATE/mint/customer-interactions/index.ndjson")),
        "lock_file": _expand_storage_path(storage.get("lock_file", "$SPINE_STATE/locks/mint-customer-interactions.lock")),
        "callback_records_root": _expand_storage_path(storage.get("callback_records_root", "$SPINE_STATE/mint/customer-voice-callbacks/records")),
        "callback_index_file": _expand_storage_path(storage.get("callback_index_file", "$SPINE_STATE/mint/customer-voice-callbacks/index.ndjson")),
        "callback_lock_file": _expand_storage_path(storage.get("callback_lock_file", "$SPINE_STATE/locks/mint-customer-voice-callbacks.lock")),
    }


def ensure_storage_exists() -> None:
    paths = get_interaction_storage_paths()
    paths["records_root"].mkdir(parents=True, exist_ok=True)
    paths["callback_records_root"].mkdir(parents=True, exist_ok=True)
    paths["lock_file"].parent.mkdir(parents=True, exist_ok=True)
    paths["callback_lock_file"].parent.mkdir(parents=True, exist_ok=True)
    paths["index_file"].parent.mkdir(parents=True, exist_ok=True)
    paths["callback_index_file"].parent.mkdir(parents=True, exist_ok=True)


def acquire_lock(lock_path: Path, timeout: int = 30) -> Any:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_file = lock_path.open("a")
    start = time.time()
    while time.time() - start < timeout:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return lock_file
        except BlockingIOError:
            time.sleep(0.1)
    raise TimeoutError(f"Could not acquire lock {lock_path} within {timeout}s")


def release_lock(lock_file: Any) -> None:
    if lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
        lock_file.close()


def generate_interaction_id() -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    unique = uuid.uuid4().hex[:8]
    return f"INT-{timestamp}-{unique.upper()}"


def generate_callback_id() -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    unique = uuid.uuid4().hex[:8]
    return f"CALLBACK-{timestamp}-{unique.upper()}"


def normalize_interaction_record(
    *,
    interaction_id: str,
    channel: str,
    provider: str,
    provider_call_id: str,
    started_at_utc: str,
    ended_at_utc: str,
    caller_number: str,
    caller_name: str = "",
    company: str = "",
    reason: str = "",
    urgency: str = "medium",
    callback_requested: bool = False,
    preferred_followup_channel: str = "email",
    order_or_quote_ref: str = "",
    disposition: str = "question_answered",
    summary: str = "",
    transcript_ref: str = "",
    linked_callback_item_id: str = "",
    live_transfer_attempted: bool = False,
    live_transfer_result: str = "",
    operator_followup_required: bool = False,
    evidence_refs: list[str] | None = None,
) -> dict[str, Any]:
    return {
        "interaction_id": interaction_id,
        "channel": channel,
        "provider": provider,
        "provider_call_id": provider_call_id,
        "started_at_utc": started_at_utc,
        "ended_at_utc": ended_at_utc,
        "caller_number": caller_number,
        "caller_name": caller_name,
        "company": company,
        "reason": reason,
        "urgency": urgency,
        "callback_requested": callback_requested,
        "preferred_followup_channel": preferred_followup_channel,
        "order_or_quote_ref": order_or_quote_ref,
        "disposition": disposition,
        "summary": summary,
        "transcript_ref": transcript_ref,
        "linked_callback_item_id": linked_callback_item_id,
        "live_transfer_attempted": live_transfer_attempted,
        "live_transfer_result": live_transfer_result,
        "operator_followup_required": operator_followup_required,
        "evidence_refs": evidence_refs or [],
    }


def normalize_callback_queue_item(
    *,
    callback_item_id: str,
    interaction_id: str,
    caller_number: str,
    caller_name: str = "",
    company: str = "",
    email: str = "",
    reason: str = "",
    urgency: str = "medium",
    preferred_followup_channel: str = "email",
    order_or_quote_ref: str = "",
    summary: str = "",
    created_at_utc: str = "",
    status: str = "pending",
    assigned_to: str = "",
    completed_at_utc: str = "",
    completion_notes: str = "",
) -> dict[str, Any]:
    if not created_at_utc:
        created_at_utc = datetime.now(timezone.utc).isoformat()
    return {
        "callback_item_id": callback_item_id,
        "interaction_id": interaction_id,
        "caller_number": caller_number,
        "caller_name": caller_name,
        "company": company,
        "email": email,
        "reason": reason,
        "urgency": urgency,
        "preferred_followup_channel": preferred_followup_channel,
        "order_or_quote_ref": order_or_quote_ref,
        "summary": summary,
        "created_at_utc": created_at_utc,
        "status": status,
        "assigned_to": assigned_to,
        "completed_at_utc": completed_at_utc,
        "completion_notes": completion_notes,
    }


def write_interaction_record(record: dict[str, Any], dry_run: bool = False) -> Path:
    paths = get_interaction_storage_paths()
    interaction_id = record["interaction_id"]
    record_path = paths["records_root"] / f"{interaction_id}.json"

    if dry_run:
        return record_path

    ensure_storage_exists()
    lock_file = acquire_lock(paths["lock_file"])
    try:
        record_path.write_text(json.dumps(record, indent=2, ensure_ascii=False))
        index_entry = {
            "interaction_id": interaction_id,
            "channel": record.get("channel"),
            "provider": record.get("provider"),
            "started_at_utc": record.get("started_at_utc"),
            "caller_number": record.get("caller_number"),
            "disposition": record.get("disposition"),
        }
        with paths["index_file"].open("a") as f:
            f.write(json.dumps(index_entry, ensure_ascii=False) + "\n")
    finally:
        release_lock(lock_file)

    return record_path


def write_callback_queue_item(item: dict[str, Any], dry_run: bool = False) -> Path:
    paths = get_interaction_storage_paths()
    callback_item_id = item["callback_item_id"]
    item_path = paths["callback_records_root"] / f"{callback_item_id}.json"

    if dry_run:
        return item_path

    ensure_storage_exists()
    lock_file = acquire_lock(paths["callback_lock_file"])
    try:
        item_path.write_text(json.dumps(item, indent=2, ensure_ascii=False))
        index_entry = {
            "callback_item_id": callback_item_id,
            "interaction_id": item.get("interaction_id"),
            "caller_number": item.get("caller_number"),
            "created_at_utc": item.get("created_at_utc"),
            "status": item.get("status"),
            "urgency": item.get("urgency"),
        }
        with paths["callback_index_file"].open("a") as f:
            f.write(json.dumps(index_entry, ensure_ascii=False) + "\n")
    finally:
        release_lock(lock_file)

    return item_path


def callback_exists(interaction_id: str) -> bool:
    paths = get_interaction_storage_paths()
    if not paths["callback_index_file"].exists():
        return False

    with paths["callback_index_file"].open("r") as f:
        for line in f:
            entry = json.loads(line)
            if entry.get("interaction_id") == interaction_id:
                return True
    return False


def write_evidence_artifact(payload: str, interaction_id: str, dry_run: bool = False) -> Path:
    paths = get_interaction_storage_paths()
    evidence_dir = paths["records_root"] / "evidence"
    artifact_path = evidence_dir / f"{interaction_id}-raw-payload.json"

    if dry_run:
        return artifact_path

    evidence_dir.mkdir(parents=True, exist_ok=True)
    artifact_path.write_text(payload, encoding="utf-8")
    return artifact_path
