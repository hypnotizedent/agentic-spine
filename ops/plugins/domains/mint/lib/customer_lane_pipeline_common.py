from __future__ import annotations

import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from customer_identity_common import normalize_space
from operator_mail_common import (
    append_ndjson,
    latest_customer_message_text,
    message_sender,
    message_subject,
    write_json,
)


SCHEMA_VERSION = "1.0"


def parse_anchor_timestamp(value: str) -> datetime:
    text = normalize_space(value)
    if not text:
        return datetime.now(timezone.utc)
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return datetime.now(timezone.utc)


def build_message_anchor(mailbox: str, message: dict[str, Any], *, latest_text: str = "") -> dict[str, str]:
    return {
        "mailbox": normalize_space(mailbox),
        "message_id": normalize_space(message.get("id") or ""),
        "conversation_id": normalize_space(message.get("conversationId") or ""),
        "from": normalize_space(message_sender(message)),
        "subject": normalize_space(message_subject(message)),
        "received_at": normalize_space(message.get("receivedDateTime") or ""),
        "normalized_latest_customer_text": normalize_space(latest_text or latest_customer_message_text(message)),
    }


def disposition_gate_status(disposition: str, repair_reasons: list[str] | None = None) -> str:
    if repair_reasons:
        return "repair"
    normalized = normalize_space(disposition)
    if normalized in {"customer_actionable", "unsupported_scope", "supplier_marketing", "risky_junk"}:
        return "go"
    if normalized in {"waiting_on_customer", "vendor_revision"}:
        return "hold"
    return "hold"


def intake_record_id(anchor: dict[str, str]) -> str:
    digest = hashlib.sha256(
        "|".join(
            [
                normalize_space(anchor.get("mailbox") or ""),
                normalize_space(anchor.get("message_id") or ""),
                normalize_space(anchor.get("conversation_id") or ""),
                normalize_space(anchor.get("from") or ""),
            ]
        ).encode("utf-8")
    ).hexdigest()[:12]
    return f"MCII-{digest.upper()}"


def ensure_intake_record(
    state_root: Path,
    mailbox: str,
    message: dict[str, Any],
    *,
    latest_text: str = "",
) -> dict[str, Any]:
    anchor = build_message_anchor(mailbox, message, latest_text=latest_text)
    intake_id = intake_record_id(anchor)
    stamped = parse_anchor_timestamp(anchor.get("received_at") or "")
    records_dir = state_root / "mint" / "customer-inbox-intakes" / "records" / stamped.strftime("%Y") / stamped.strftime("%m") / stamped.strftime("%d")
    record_file = records_dir / f"{intake_id}.json"
    index_file = state_root / "mint" / "customer-inbox-intakes" / "index.ndjson"
    lock_file = state_root / "mint" / "customer-inbox-intakes" / ".index.lock"
    payload = {
        "capability": "mint.customer.inbox.intake",
        "schema_version": SCHEMA_VERSION,
        "intake_id": intake_id,
        "message_anchor": anchor,
    }
    if not record_file.exists():
        write_json(record_file, payload)
        append_ndjson(
            index_file,
            lock_file,
            {
                "intake_id": intake_id,
                "message_id": anchor.get("message_id"),
                "conversation_id": anchor.get("conversation_id"),
                "mailbox": anchor.get("mailbox"),
                "record_file": str(record_file),
                "received_at": anchor.get("received_at"),
            },
        )
    return {
        "intake_id": intake_id,
        "record_file": str(record_file),
        "index_file": str(index_file),
        "message_anchor": anchor,
    }
