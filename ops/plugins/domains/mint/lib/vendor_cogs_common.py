from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


CONTRACT_FALLBACK = "ops/bindings/mint.finance.vendor.receipt.cogs.contract.yaml"


def normalize_text(value: Any) -> str:
    return str(value or "").strip()


def resolve_contract_path(spine_root: Path) -> Path:
    override = normalize_text(os.environ.get("MINT_VENDOR_RECEIPT_COGS_CONTRACT"))
    if override:
        path = Path(override).expanduser().resolve()
    else:
        path = (spine_root / CONTRACT_FALLBACK).resolve()
    if not path.is_file():
        raise FileNotFoundError(f"vendor COGS contract not found: {path}")
    return path


def load_contract(contract_path: Path) -> dict[str, Any]:
    payload = yaml.safe_load(contract_path.read_text(encoding="utf-8")) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"invalid vendor COGS contract: {contract_path}")
    return payload


def resolve_state_path(raw: str, *, spine_root: Path, state_root: Path) -> Path:
    value = normalize_text(raw).replace("$SPINE_ROOT", str(spine_root)).replace("$SPINE_STATE", str(state_root))
    return Path(value).expanduser().resolve()


def runtime_paths(*, spine_root: Path, state_root: Path) -> dict[str, Path]:
    contract = load_contract(resolve_contract_path(spine_root))
    storage = dict(contract.get("storage") or {})
    vendor_receipts = dict(storage.get("vendor_receipts") or {})
    finance_cogs = dict(storage.get("finance_cogs_evidence") or {})
    return {
        "contract_path": resolve_contract_path(spine_root),
        "vendor_receipts_records_root": resolve_state_path(
            str(vendor_receipts.get("records_root") or ""),
            spine_root=spine_root,
            state_root=state_root,
        ),
        "vendor_receipts_index_file": resolve_state_path(
            str(vendor_receipts.get("index_file") or ""),
            spine_root=spine_root,
            state_root=state_root,
        ),
        "vendor_receipts_lock_file": resolve_state_path(
            str(vendor_receipts.get("lock_file") or ""),
            spine_root=spine_root,
            state_root=state_root,
        ),
        "finance_cogs_records_root": resolve_state_path(
            str(finance_cogs.get("records_root") or ""),
            spine_root=spine_root,
            state_root=state_root,
        ),
        "finance_cogs_index_file": resolve_state_path(
            str(finance_cogs.get("index_file") or ""),
            spine_root=spine_root,
            state_root=state_root,
        ),
        "finance_cogs_lock_file": resolve_state_path(
            str(finance_cogs.get("lock_file") or ""),
            spine_root=spine_root,
            state_root=state_root,
        ),
        "evidence_root": resolve_state_path(
            str(storage.get("evidence_root") or ""),
            spine_root=spine_root,
            state_root=state_root,
        ),
    }


def iso_to_parts(value: str) -> tuple[str, str, str]:
    raw = normalize_text(value)
    if not raw:
        now = datetime.now(timezone.utc)
        return now.strftime("%Y"), now.strftime("%m"), now.strftime("%d")
    for fmt in (
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S.%fZ",
        "%Y-%m-%d %H:%M:%S%z",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
    ):
        try:
            parsed = datetime.strptime(raw, fmt)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            parsed = parsed.astimezone(timezone.utc)
            return parsed.strftime("%Y"), parsed.strftime("%m"), parsed.strftime("%d")
        except ValueError:
            continue
    return raw[:4], raw[5:7], raw[8:10]


def dated_record_path(root: Path, timestamp: str, record_id: str, suffix: str = ".json") -> Path:
    year, month, day = iso_to_parts(timestamp)
    return root / year / month / day / f"{record_id}{suffix}"


def deterministic_id(prefix: str, *parts: str) -> str:
    digest = hashlib.sha1("||".join(normalize_text(part) for part in parts).encode("utf-8")).hexdigest()
    return f"{prefix}-{digest[:12]}"


def read_ndjson(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    out: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        text = line.strip()
        if not text:
            continue
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            out.append(payload)
    return out


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return payload if isinstance(payload, dict) else {}


def vendor_receipt_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    external_order_ref = dict(record.get("external_order_ref") or {})
    return {
        "vendor_receipt_id": record.get("vendor_receipt_id"),
        "vendor_id": record.get("vendor_id"),
        "mailbox": record.get("mailbox"),
        "source_message_id": record.get("source_message_id"),
        "source_internet_message_id": record.get("source_internet_message_id"),
        "source_conversation_id": record.get("source_conversation_id"),
        "received_at_utc": record.get("received_at_utc"),
        "event_primary": record.get("event_primary"),
        "event_kinds": record.get("event_kinds"),
        "vendor_order_number": (record.get("extracted_fields") or {}).get("vendor_order_number"),
        "external_system": external_order_ref.get("external_system"),
        "external_order_number": external_order_ref.get("external_order_number"),
        "seed_id": external_order_ref.get("seed_id"),
        "customer_id": external_order_ref.get("customer_id"),
        "customer_email": external_order_ref.get("customer_email"),
        "printavo_bridge_id": external_order_ref.get("printavo_bridge_id"),
        "record_file": record.get("record_file"),
    }


def finance_evidence_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    external_order_ref = dict(record.get("external_order_ref") or {})
    normalized_extract = dict(record.get("normalized_extract") or {})
    totals = dict(normalized_extract.get("totals") or {})
    provenance = dict(record.get("provenance") or {})
    return {
        "finance_evidence_id": record.get("finance_evidence_id"),
        "vendor_receipt_id": record.get("vendor_receipt_id"),
        "vendor_id": record.get("vendor_id"),
        "event_primary": record.get("event_primary"),
        "cogs_visibility_state": record.get("cogs_visibility_state"),
        "cost_basis_status": record.get("cost_basis_status"),
        "source_message_id": provenance.get("source_message_id"),
        "vendor_order_number": normalized_extract.get("vendor_order_number"),
        "external_system": external_order_ref.get("external_system"),
        "external_order_number": external_order_ref.get("external_order_number"),
        "seed_id": external_order_ref.get("seed_id"),
        "customer_id": external_order_ref.get("customer_id"),
        "customer_email": external_order_ref.get("customer_email"),
        "printavo_bridge_id": external_order_ref.get("printavo_bridge_id"),
        "total_cents": totals.get("total_cents"),
        "received_at_utc": record.get("received_at_utc"),
        "record_file": record.get("record_file"),
    }


def record_sort_timestamp(record: dict[str, Any]) -> str:
    return normalize_text(
        record.get("received_at_utc")
        or record.get("recorded_at_utc")
        or record.get("captured_at_utc")
        or record.get("created_at")
    )
