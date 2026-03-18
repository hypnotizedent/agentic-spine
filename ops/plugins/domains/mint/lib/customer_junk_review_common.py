from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import yaml

LIB_DIR = Path(__file__).resolve().parent
COMM_LIB_DIR = LIB_DIR.parent.parent / "communications" / "lib"
if str(COMM_LIB_DIR) not in sys.path:
    sys.path.insert(0, str(COMM_LIB_DIR))

from mail_triage_classifier import classify_message
from customer_inbox_disposition_common import business_signal, combined_message_text, load_disposition_contract, resolve_message_disposition
from operator_mail_common import (
    append_ndjson,
    iso_utc,
    latest_customer_message_text,
    message_sender,
    message_subject,
    normalized_subject,
    resolve_spine_root,
    resolve_spine_state,
    run_cap_capture,
    utc_now,
    write_json,
)


REVIEW_CONTRACT_FALLBACK = "ops/bindings/mint.customer.junk.review.contract.yaml"
DEFAULT_FOLDER_MESSAGES_CAPABILITY = "microsoft.mail.folder.messages"
DEFAULT_FOLDER_ENSURE_CAPABILITY = "microsoft.mail.folder.ensure"
DEFAULT_GET_CAPABILITY = "microsoft.mail.get"
DEFAULT_MOVE_CAPABILITY = "microsoft.mail.move"


def normalize_space(value: Any) -> str:
    return " ".join(str(value or "").split()).strip()


def load_yaml_file(path: Path) -> dict[str, Any]:
    try:
        payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError):
        return {}
    return payload if isinstance(payload, dict) else {}


def load_review_contract(spine_root: Path) -> dict[str, Any]:
    override = normalize_space(os.environ.get("MINT_CUSTOMER_JUNK_REVIEW_CONTRACT") or "")
    if override:
        path = Path(override).expanduser().resolve()
    else:
        path = (spine_root / REVIEW_CONTRACT_FALLBACK).resolve()
    if not path.is_file():
        raise SystemExit(f"missing contract: {path}")
    raw = load_yaml_file(path)
    return {
        "path": str(path),
        "surface": dict(raw.get("surface") or {}),
        "storage": dict(raw.get("storage") or {}),
        "workflow": dict(raw.get("workflow") or {}),
    }


def truncate_text(text: str, limit: int = 240) -> str:
    normalized = normalize_space(text)
    if len(normalized) <= limit:
        return normalized
    return normalized[: limit - 3].rstrip() + "..."


def classify_review_action(disposition_name: str, contract: dict[str, Any]) -> dict[str, str]:
    actions = dict((contract.get("workflow") or {}).get("classification_actions") or {})
    if disposition_name == "supplier_marketing":
        config = dict(actions.get("supplier_marketing") or {})
    elif disposition_name == "risky_junk":
        config = dict(actions.get("risky_junk") or {})
    else:
        config = dict(actions.get("restore_default") or {})
    return {
        "review_class": normalize_space(config.get("review_class") or "real_customer_false_positive"),
        "action": normalize_space(config.get("action") or "restore_to_inbox"),
        "destination_folder": normalize_space(config.get("destination_folder") or "Inbox"),
    }


def ensure_destination_folder(spine_root: Path, mailbox: str, folder_name: str, contract: dict[str, Any]) -> tuple[dict[str, Any], str]:
    workflow = dict(contract.get("workflow") or {})
    folder_ensure_capability = normalize_space(workflow.get("folder_ensure_capability") or DEFAULT_FOLDER_ENSURE_CAPABILITY)
    return run_cap_capture(
        spine_root,
        folder_ensure_capability,
        ["--mailbox", mailbox, "--display-name", folder_name],
    )


def restore_candidate(message: dict[str, Any], disposition: dict[str, Any], spine_root: Path) -> bool:
    disposition_name = normalize_space(disposition.get("disposition") or "")
    if disposition_name in {"customer_actionable", "unsupported_scope", "vendor_revision"}:
        return True
    if disposition_name != "waiting_on_customer":
        return False
    text = combined_message_text(message)
    if business_signal(text, load_disposition_contract(spine_root)):
        return True
    customer_contact = dict(disposition.get("customer_contact") or {})
    if normalize_space(customer_contact.get("mode") or "") in {"mailbox_participant", "forwarded_body"}:
        return True
    return False


def review_defaults(contract: dict[str, Any]) -> dict[str, Any]:
    surface = dict(contract.get("surface") or {})
    return {
        "mailbox": normalize_space(surface.get("default_mailbox") or "team@mintprints.com"),
        "folder": normalize_space(surface.get("source_folder") or "Junk Email"),
        "top": int(surface.get("review_top") or 50),
        "order": normalize_space(surface.get("review_order") or "newest_first") or "newest_first",
    }


def build_junk_review(
    spine_root: Path,
    *,
    mailbox: str,
    folder: str,
    top: int,
    order: str,
) -> dict[str, Any]:
    contract = load_review_contract(spine_root)
    workflow = dict(contract.get("workflow") or {})
    folder_messages_capability = normalize_space(workflow.get("folder_messages_capability") or DEFAULT_FOLDER_MESSAGES_CAPABILITY)
    get_capability = normalize_space(workflow.get("source_get_capability") or DEFAULT_GET_CAPABILITY)
    hydrate_review_classes = {
        normalize_space(item)
        for item in (workflow.get("hydrate_full_message_for_review_classes") or ["real_customer_false_positive"])
        if normalize_space(item)
    }

    folder_payload, folder_receipt = run_cap_capture(
        spine_root,
        folder_messages_capability,
        ["--mailbox", mailbox, "--folder", folder, "--top", str(top), "--order", order],
    )

    items: list[dict[str, Any]] = []
    counts = {
        "supplier_marketing": 0,
        "risky_junk": 0,
        "real_customer_false_positive": 0,
    }
    message_get_receipts: dict[str, str] = {}
    hydration_errors: dict[str, str] = {}

    for entry in folder_payload.get("value") or []:
        if not isinstance(entry, dict):
            continue
        message_id = normalize_space(entry.get("id") or "")
        if not message_id:
            continue
        message = dict(entry)
        preview_disposition = resolve_message_disposition(spine_root, message)
        preview_action = classify_review_action(str(preview_disposition.get("disposition") or ""), contract)
        triage_class, triage_recommended_action, triage_basis = classify_message(
            message_sender(message) or message_sender(entry),
            message_subject(message) or message_subject(entry),
            latest_customer_message_text(message) or latest_customer_message_text(entry),
        )
        if preview_action["review_class"] == "real_customer_false_positive" and triage_class != "customer_or_operator":
            preview_action = classify_review_action("risky_junk", contract)
        if preview_action["review_class"] == "real_customer_false_positive" and not restore_candidate(message, preview_disposition, spine_root):
            preview_action = classify_review_action("risky_junk", contract)
        hydration_mode = "preview_only"
        hydration_error = ""
        get_receipt = ""
        disposition = preview_disposition
        action = preview_action
        if preview_action["review_class"] in hydrate_review_classes:
            try:
                hydrated_message, get_receipt = run_cap_capture(
                    spine_root,
                    get_capability,
                    ["--message-id", message_id, "--mailbox", mailbox],
                )
                if isinstance(hydrated_message, dict) and normalize_space(hydrated_message.get("id") or ""):
                    message = hydrated_message
                    hydration_mode = "full_body"
                    disposition = resolve_message_disposition(spine_root, message)
                    action = classify_review_action(str(disposition.get("disposition") or ""), contract)
            except SystemExit:
                hydration_error = f"{get_capability} failed"
        review_class = action["review_class"]
        counts[review_class] = counts.get(review_class, 0) + 1
        if get_receipt:
            message_get_receipts[message_id] = get_receipt
        if hydration_error:
            hydration_errors[message_id] = hydration_error

        items.append(
            {
                "message_id": message_id,
                "received_utc": normalize_space(message.get("receivedDateTime") or entry.get("receivedDateTime") or ""),
                "sender": message_sender(message) or message_sender(entry),
                "subject": message_subject(message) or message_subject(entry),
                "normalized_subject": normalized_subject(message_subject(message) or message_subject(entry)),
                "disposition": normalize_space(disposition.get("disposition") or ""),
                "reason_codes": list(disposition.get("reason_codes") or []),
                "review_class": review_class,
                "action": action["action"],
                "destination_folder": action["destination_folder"],
                "hydration_mode": hydration_mode,
                "hydration_error": hydration_error,
                "body_excerpt": truncate_text(latest_customer_message_text(message) or latest_customer_message_text(entry)),
                "conversation_id": normalize_space(message.get("conversationId") or entry.get("conversationId") or ""),
                "internet_message_id": normalize_space(message.get("internetMessageId") or entry.get("internetMessageId") or ""),
                "has_attachments": bool(message.get("hasAttachments") or entry.get("hasAttachments")),
                "customer_truth_allowed": bool(disposition.get("customer_truth_allowed")),
                "primary_queue_visible": bool(disposition.get("primary_queue_visible")),
                "reply_allowed": bool(disposition.get("reply_allowed")),
                "triage_class": triage_class,
                "triage_recommended_action": triage_recommended_action,
                "triage_basis": triage_basis,
            }
        )

    return {
        "contract_file": contract.get("path"),
        "mailbox": mailbox,
        "source_folder_requested": folder,
        "source_folder_id": normalize_space(folder_payload.get("folderId") or ""),
        "source_folder_display_name": normalize_space(folder_payload.get("folderDisplayName") or folder),
        "order": order,
        "top": top,
        "reviewed_count": len(items),
        "counts": counts,
        "items": items,
        "receipts": {
            "folder_messages_receipt": folder_receipt or None,
            "message_get_receipts": message_get_receipts,
        },
        "hydration_errors": hydration_errors,
    }


def persist_record(
    state_root: Path,
    *,
    category: str,
    artifact_id: str,
    payload: dict[str, Any],
    stored_at,
) -> tuple[Path, Path]:
    records_dir = state_root / "mint" / category / "records" / stored_at.strftime("%Y") / stored_at.strftime("%m") / stored_at.strftime("%d")
    index_file = state_root / "mint" / category / "index.ndjson"
    lock_file = state_root / "locks" / f"mint-{category}.lock"
    record_file = records_dir / f"{artifact_id}.json"
    write_json(record_file, payload)
    append_ndjson(
        index_file,
        lock_file,
        {
            "artifact_id": artifact_id,
            "status": str(payload.get("status") or ""),
            "mailbox": str(payload.get("mailbox") or ""),
            "source_folder_display_name": str(payload.get("source_folder_display_name") or ""),
            "reviewed_count": int(payload.get("reviewed_count") or 0),
            "record_file": str(record_file),
            "stored_at_utc": iso_utc(stored_at),
        },
    )
    return record_file, index_file


def resolve_runtime() -> tuple[Path, Path]:
    spine_root = resolve_spine_root()
    state_root = resolve_spine_state(spine_root)
    return spine_root, state_root


def default_review_kwargs() -> dict[str, Any]:
    spine_root = resolve_spine_root()
    contract = load_review_contract(spine_root)
    return review_defaults(contract)


def encode_json(payload: dict[str, Any]) -> str:
    return json.dumps(payload, indent=2, sort_keys=True)


def new_artifact_id(prefix: str) -> tuple[str, Any]:
    now = utc_now()
    return f"{prefix}-{now.strftime('%Y%m%dT%H%M%SZ')}-{os.urandom(2).hex()}", now
