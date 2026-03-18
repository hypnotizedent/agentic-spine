from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from operator_mail_common import append_ndjson, compact_utc, iso_utc, utc_now, write_json


def record_customer_repair_item(
    state_root: Path,
    *,
    issue_type: str,
    mailbox: str,
    message_id: str,
    source_subject: str,
    source_from: str,
    capability: str,
    note: str,
    expected: dict[str, Any] | None = None,
    observed: dict[str, Any] | None = None,
) -> dict[str, Any]:
    now = utc_now()
    repair_id = f"MCR-{compact_utc(now)}-{os.urandom(2).hex()}"
    record = {
        "repair_id": repair_id,
        "stored_at_utc": iso_utc(now),
        "issue_type": issue_type,
        "mailbox": mailbox,
        "message_id": message_id,
        "source_subject": source_subject or None,
        "source_from": source_from or None,
        "capability": capability,
        "note": note,
        "expected": dict(expected or {}),
        "observed": dict(observed or {}),
    }
    record_file = (
        state_root
        / "mint"
        / "customer-repair-items"
        / "records"
        / now.strftime("%Y")
        / now.strftime("%m")
        / now.strftime("%d")
        / f"{repair_id}.json"
    )
    index_file = state_root / "mint" / "customer-repair-items" / "index.ndjson"
    lock_file = state_root / "locks" / "mint-customer-repair-items.lock"
    write_json(record_file, record)
    append_ndjson(
        index_file,
        lock_file,
        {
            "repair_id": repair_id,
            "stored_at_utc": record["stored_at_utc"],
            "issue_type": issue_type,
            "mailbox": mailbox,
            "message_id": message_id,
            "capability": capability,
            "record_file": str(record_file),
        },
    )
    record["record_file"] = str(record_file)
    record["index_file"] = str(index_file)
    return record
