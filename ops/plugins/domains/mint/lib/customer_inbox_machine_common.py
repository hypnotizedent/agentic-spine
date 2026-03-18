from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any

import yaml

from customer_lane_pipeline_common import build_message_anchor
from operator_mail_common import append_ndjson, iso_utc, message_body_text, utc_now, write_json


CONTRACT_ENV = "MINT_CUSTOMER_INBOX_MACHINE_CONTRACT"
CONTRACT_FALLBACK = "ops/bindings/mint.customer.inbox.machine.contract.yaml"
SCHEMA_VERSION = "1.0"


def normalize_space(value: Any) -> str:
    return " ".join(str(value or "").split())


def load_machine_contract(spine_root: Path) -> dict[str, Any]:
    override = normalize_space(os.environ.get(CONTRACT_ENV) or "")
    if override:
        path = Path(override).expanduser().resolve()
    else:
        candidate = (spine_root / CONTRACT_FALLBACK).resolve()
        if candidate.is_file():
            path = candidate
        else:
            path = (Path(__file__).resolve().parents[5] / CONTRACT_FALLBACK).resolve()
    if not path.is_file():
        raise SystemExit(f"missing contract: {path}")
    try:
        payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        raise SystemExit(f"invalid contract: {path}") from exc
    surface = dict(payload.get("surface") or {})
    source_mailboxes = dict(payload.get("source_mailboxes") or {})
    state_mapping = dict(payload.get("state_mapping") or {})
    promote_comment = dict(payload.get("promote_comment") or {})
    return {
        "path": str(path),
        "surface": surface,
        "source_mailboxes": source_mailboxes,
        "states": dict(payload.get("states") or {}),
        "state_mapping": state_mapping,
        "source_modes": dict(payload.get("source_modes") or {}),
        "reply_anchor_modes": dict(payload.get("reply_anchor_modes") or {}),
        "promote_comment": promote_comment,
        "canonical_mailbox": normalize_space(surface.get("canonical_mailbox") or source_mailboxes.get("canonical_team_mailbox") or ""),
        "promote_allowed_source_mailboxes": [
            normalize_space(item).lower()
            for item in (source_mailboxes.get("promote_allowed_source_mailboxes") or [])
            if normalize_space(item)
        ],
        "promote_source_park_folder": normalize_space(source_mailboxes.get("promote_source_park_folder") or ""),
        "preserve_on_sync": {
            normalize_space(item)
            for item in (state_mapping.get("preserve_on_sync") or [])
            if normalize_space(item)
        },
        "allowed_manual_transitions": {
            normalize_space(item)
            for item in (state_mapping.get("allowed_manual_transitions") or [])
            if normalize_space(item)
        },
        "disposition_defaults": {
            normalize_space(key): normalize_space(value)
            for key, value in dict(state_mapping.get("disposition_defaults") or {}).items()
            if normalize_space(key) and normalize_space(value)
        },
        "promote_header": normalize_space(promote_comment.get("header") or "MINT TEAM PROMOTE"),
        "promote_footer": normalize_space(promote_comment.get("footer") or "END MINT TEAM PROMOTE"),
    }


def default_workflow_state(disposition: str, contract: dict[str, Any]) -> str:
    return normalize_space((contract.get("disposition_defaults") or {}).get(normalize_space(disposition)) or "queued")


def _promote_block_pattern(header: str, footer: str) -> re.Pattern[str]:
    return re.compile(
        rf"{re.escape(header)}\s*(.*?)\s*{re.escape(footer)}",
        flags=re.IGNORECASE | re.DOTALL,
    )


def parse_promote_metadata_from_text(text: str, contract: dict[str, Any]) -> dict[str, str]:
    clean = str(text or "")
    if not clean:
        return {}
    match = _promote_block_pattern(
        str(contract.get("promote_header") or "MINT TEAM PROMOTE"),
        str(contract.get("promote_footer") or "END MINT TEAM PROMOTE"),
    ).search(clean)
    if not match:
        return {}
    data: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        clean_key = normalize_space(key).lower().replace(" ", "_")
        clean_value = normalize_space(value)
        if clean_key and clean_value:
            data[clean_key] = clean_value
    return data


def parse_promote_metadata(message: dict[str, Any], contract: dict[str, Any]) -> dict[str, str]:
    text = message_body_text(message)
    return parse_promote_metadata_from_text(text, contract)


def render_promote_comment(
    *,
    contract: dict[str, Any],
    promote_id: str,
    source_mailbox: str,
    target_mailbox: str,
    source_message: dict[str, Any],
    source_customer_email: str,
) -> str:
    body_lines = [
        str(contract.get("promote_header") or "MINT TEAM PROMOTE"),
        f"promote_id: {normalize_space(promote_id)}",
        f"source_mailbox: {normalize_space(source_mailbox).lower()}",
        f"source_message_id: {normalize_space(source_message.get('id') or '')}",
        f"source_received_at: {normalize_space(source_message.get('receivedDateTime') or '')}",
        f"source_from: {normalize_space((((source_message.get('from') or {}).get('emailAddress') or {}).get('address')) or '')}",
        f"source_subject: {normalize_space(source_message.get('subject') or '')}",
        f"source_customer_email: {normalize_space(source_customer_email).lower()}",
        f"target_mailbox: {normalize_space(target_mailbox).lower()}",
        "reply_anchor_mode: fresh_outbound",
        "note: Governed promote into the canonical Mint team inbox.",
        str(contract.get("promote_footer") or "END MINT TEAM PROMOTE"),
        "",
        "Promoted into team@ so Morpheus can handle this through the canonical Mint inbox lane.",
    ]
    return "\n".join(body_lines).strip()


def source_context_for_message(
    *,
    contract: dict[str, Any],
    mailbox: str,
    message: dict[str, Any],
    latest_text: str = "",
) -> dict[str, Any]:
    team_anchor = build_message_anchor(mailbox, message, latest_text=latest_text)
    promote_metadata = parse_promote_metadata(message, contract)
    if promote_metadata:
        source_anchor = {
            "mailbox": normalize_space(promote_metadata.get("source_mailbox") or ""),
            "message_id": normalize_space(promote_metadata.get("source_message_id") or ""),
            "conversation_id": "",
            "from": normalize_space(promote_metadata.get("source_from") or ""),
            "subject": normalize_space(promote_metadata.get("source_subject") or ""),
            "received_at": normalize_space(promote_metadata.get("source_received_at") or ""),
            "normalized_latest_customer_text": normalize_space(latest_text),
        }
        return {
            "team_message_anchor": team_anchor,
            "source_message_anchor": source_anchor,
            "source_mode": "promoted_forward",
            "reply_anchor_mode": "fresh_outbound",
            "promote_metadata": promote_metadata,
        }
    return {
        "team_message_anchor": team_anchor,
        "source_message_anchor": dict(team_anchor),
        "source_mode": "team_direct",
        "reply_anchor_mode": "reply_chain",
        "promote_metadata": {},
    }


def inbox_item_id_from_anchor(anchor: dict[str, Any]) -> str:
    digest = hashlib.sha256(
        "|".join(
            [
                normalize_space(anchor.get("mailbox") or "").lower(),
                normalize_space(anchor.get("message_id") or ""),
                normalize_space(anchor.get("from") or "").lower(),
                normalize_space(anchor.get("subject") or ""),
            ]
        ).encode("utf-8")
    ).hexdigest()[:12]
    return f"MII-{digest.upper()}"


def _current_dir(state_root: Path) -> Path:
    return state_root / "mint" / "customer-inbox-items" / "current"


def _index_file(state_root: Path) -> Path:
    return state_root / "mint" / "customer-inbox-items" / "index.ndjson"


def _lock_file(state_root: Path) -> Path:
    return state_root / "locks" / "mint-customer-inbox-items.lock"


def _message_ref_dir(state_root: Path) -> Path:
    return state_root / "mint" / "customer-inbox-items" / "by-message-id"


def _item_ref_file(state_root: Path, inbox_item_id: str) -> Path:
    return _current_dir(state_root) / f"{normalize_space(inbox_item_id)}.json"


def _message_ref_file(state_root: Path, message_id: str) -> Path:
    return _message_ref_dir(state_root) / f"{normalize_space(message_id)}.json"


def load_inbox_item_by_id(state_root: Path, inbox_item_id: str) -> dict[str, Any]:
    path = _item_ref_file(state_root, inbox_item_id)
    if not path.is_file():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return dict(payload or {})


def load_inbox_item_by_message_id(state_root: Path, message_id: str) -> dict[str, Any]:
    ref_path = _message_ref_file(state_root, message_id)
    if not ref_path.is_file():
        return {}
    try:
        payload = json.loads(ref_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    inbox_item_id = normalize_space(payload.get("inbox_item_id") or "")
    if not inbox_item_id:
        return {}
    return load_inbox_item_by_id(state_root, inbox_item_id)


def _write_message_ref(state_root: Path, message_id: str, inbox_item_id: str) -> None:
    path = _message_ref_file(state_root, message_id)
    write_json(
        path,
        {
            "message_id": normalize_space(message_id),
            "inbox_item_id": normalize_space(inbox_item_id),
            "record_file": str(_item_ref_file(state_root, inbox_item_id)),
        },
    )


def _merge_workflow_state(existing: dict[str, Any], new_default_state: str, contract: dict[str, Any]) -> str:
    existing_state = normalize_space(existing.get("workflow_state") or "")
    if existing_state and existing_state in set(contract.get("preserve_on_sync") or set()):
        return existing_state
    return normalize_space(new_default_state or existing_state or "queued")


def sync_inbox_item(
    state_root: Path,
    *,
    contract: dict[str, Any],
    mailbox: str,
    effective_message: dict[str, Any],
    work_item: dict[str, Any],
) -> dict[str, Any]:
    source_context = source_context_for_message(
        contract=contract,
        mailbox=mailbox,
        message=effective_message,
        latest_text=str(((work_item.get("message_anchor") or {}).get("normalized_latest_customer_text")) or ""),
    )
    inbox_item_id = inbox_item_id_from_anchor(source_context["source_message_anchor"])
    current = load_inbox_item_by_id(state_root, inbox_item_id)
    now = utc_now()
    now_utc = iso_utc(now)
    workflow_state = _merge_workflow_state(
        current,
        default_workflow_state(str(work_item.get("disposition") or ""), contract),
        contract,
    )
    transition_history = list(current.get("transition_history") or [])
    record = {
        "capability": "mint.customer.inbox.machine",
        "schema_version": SCHEMA_VERSION,
        "inbox_item_id": inbox_item_id,
        "stored_at_utc": normalize_space(current.get("stored_at_utc") or now_utc),
        "updated_at_utc": now_utc,
        "mailbox": normalize_space(mailbox),
        "workflow_state": workflow_state,
        "disposition": normalize_space(work_item.get("disposition") or ""),
        "work_type": normalize_space(work_item.get("work_type") or ""),
        "primary_queue_visible": bool(work_item.get("primary_queue_visible")),
        "customer_truth_allowed": bool(work_item.get("customer_truth_allowed")),
        "reply_allowed": bool(work_item.get("reply_allowed")),
        "recoverable_folder": normalize_space(work_item.get("recoverable_folder") or ""),
        "source_mode": normalize_space(source_context.get("source_mode") or ""),
        "reply_anchor_mode": normalize_space(source_context.get("reply_anchor_mode") or ""),
        "team_message_anchor": source_context.get("team_message_anchor") or {},
        "source_message_anchor": source_context.get("source_message_anchor") or {},
        "promote_metadata": source_context.get("promote_metadata") or {},
        "operator_report": dict(work_item.get("operator_report") or {}),
        "linked_records": {
            "intake_record": dict(work_item.get("intake_record") or {}),
            "queue_source_record": str(work_item.get("record_file") or ""),
        },
        "queue_claim": dict(current.get("queue_claim") or {}),
        "transition_history": transition_history,
    }
    record_file = _item_ref_file(state_root, inbox_item_id)
    write_json(record_file, record)
    team_message_id = normalize_space(((source_context.get("team_message_anchor") or {}).get("message_id")) or "")
    if team_message_id:
        _write_message_ref(state_root, team_message_id, inbox_item_id)
    append_ndjson(
        _index_file(state_root),
        _lock_file(state_root),
        {
            "stored_at_utc": now_utc,
            "event": "sync",
            "inbox_item_id": inbox_item_id,
            "message_id": team_message_id,
            "workflow_state": workflow_state,
            "disposition": record["disposition"],
            "record_file": str(record_file),
        },
    )
    record["record_file"] = str(record_file)
    return record


def transition_inbox_item(
    state_root: Path,
    *,
    contract: dict[str, Any],
    new_state: str,
    inbox_item_id: str = "",
    message_id: str = "",
    note: str = "",
    actor: str = "",
    queue_claim: dict[str, Any] | None = None,
) -> dict[str, Any]:
    target_state = normalize_space(new_state)
    if target_state not in set(contract.get("allowed_manual_transitions") or set()):
        raise SystemExit(f"invalid inbox item state: {new_state}")
    current = load_inbox_item_by_id(state_root, inbox_item_id) if normalize_space(inbox_item_id) else {}
    if not current and normalize_space(message_id):
        current = load_inbox_item_by_message_id(state_root, message_id)
    if not current:
        raise SystemExit("inbox item not found")
    now_utc = iso_utc(utc_now())
    history = list(current.get("transition_history") or [])
    history.append(
        {
            "at_utc": now_utc,
            "state": target_state,
            "note": normalize_space(note),
            "actor": normalize_space(actor),
        }
    )
    current["workflow_state"] = target_state
    current["updated_at_utc"] = now_utc
    current["transition_history"] = history
    if queue_claim is not None:
        current["queue_claim"] = dict(queue_claim or {})
    record_file = _item_ref_file(state_root, str(current.get("inbox_item_id") or ""))
    write_json(record_file, current)
    team_message_id = normalize_space((((current.get("team_message_anchor") or {}).get("message_id")) or ""))
    if team_message_id:
        _write_message_ref(state_root, team_message_id, str(current.get("inbox_item_id") or ""))
    append_ndjson(
        _index_file(state_root),
        _lock_file(state_root),
        {
            "stored_at_utc": now_utc,
            "event": "transition",
            "inbox_item_id": current.get("inbox_item_id"),
            "message_id": team_message_id,
            "workflow_state": target_state,
            "record_file": str(record_file),
            "note": normalize_space(note),
            "actor": normalize_space(actor),
        },
    )
    current["record_file"] = str(record_file)
    return current
