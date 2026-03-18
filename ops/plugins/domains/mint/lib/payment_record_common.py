from __future__ import annotations

import copy
import json
import os
import uuid
from pathlib import Path
from typing import Any

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root as governed_resolve_spine_root
from quote_packet_normalize import dump_yaml, load_structured_file, now_utc


PAYMENT_CAPTURE_NAMESPACE = uuid.uuid5(
    uuid.NAMESPACE_URL,
    "https://spine.ronny.works/mint/payment-record-capture",
)


def resolve_spine_root() -> Path:
    return governed_resolve_spine_root(__file__)


def resolve_mint_root(spine_root: Path | None = None) -> Path:
    return resolve_mint_data_root(spine_root=spine_root, current_file=__file__)


def runtime_paths(spine_root: Path | None = None) -> dict[str, Path]:
    mint_root = resolve_mint_root(spine_root)
    return {
        "mint_root": mint_root,
        "orders_dir": Path(os.environ.get("MINT_ORDER_RUNTIME_DIR") or (mint_root / "orders")),
        "orders_index_file": Path(os.environ.get("MINT_ORDER_INDEX_FILE") or (mint_root / "orders-index.yaml")),
        "quotes_dir": Path(os.environ.get("MINT_QUOTES_DIR") or (mint_root / "quotes")),
        "quotes_index_file": Path(os.environ.get("MINT_QUOTES_INDEX_FILE") or (mint_root / "quotes-index.yaml")),
        "payment_captures_dir": Path(os.environ.get("MINT_PAYMENT_CAPTURE_DIR") or (mint_root / "payment-captures")),
        "payment_captures_index_file": Path(
            os.environ.get("MINT_PAYMENT_CAPTURE_INDEX_FILE") or (mint_root / "payment-captures-index.yaml")
        ),
    }


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


def load_yaml_object(path: Path) -> dict[str, Any]:
    payload = load_structured_file(path) if path.exists() else {}
    return payload if isinstance(payload, dict) else {}


def load_index(index_file: Path, list_key: str) -> list[dict[str, Any]]:
    payload = load_structured_file(index_file) if index_file.exists() else {}
    if not isinstance(payload, dict):
        return []
    return [copy.deepcopy(item) for item in (payload.get(list_key) or []) if isinstance(item, dict)]


def update_entity_index(index_file: Path, list_key: str, entity_key: str, entry: dict[str, Any]) -> None:
    payload = load_structured_file(index_file) if index_file.exists() else {list_key: []}
    if not isinstance(payload, dict):
        payload = {list_key: []}
    entries = payload.setdefault(list_key, [])
    existing = next(
        (
            item
            for item in entries
            if isinstance(item, dict) and str(item.get(entity_key) or "") == str(entry.get(entity_key) or "")
        ),
        None,
    )
    if existing:
        existing.update(copy.deepcopy(entry))
    else:
        entries.append(copy.deepcopy(entry))
    dump_yaml(index_file, payload)


def default_payment_summary(payment_state: str = "unpaid") -> dict[str, Any]:
    return {
        "schema_version": "1.0",
        "visibility_state": "not_yet_visible",
        "source_kind": "none",
        "record_kind": "none",
        "record_id": None,
        "payment_state": payment_state,
        "amount_cents": None,
        "currency": None,
        "captured_at": None,
        "recorded_at": None,
        "captured_by": None,
        "reference": None,
        "note": None,
    }


def payment_summary_from_manual_capture(record: dict[str, Any], timestamp: str) -> dict[str, Any]:
    return {
        "schema_version": "1.0",
        "visibility_state": "confirmed_in_records",
        "source_kind": "manual_operator_capture",
        "record_kind": "payment_capture",
        "record_id": record.get("payment_capture_id"),
        "payment_state": record.get("payment_state"),
        "amount_cents": record.get("amount_cents"),
        "currency": record.get("currency"),
        "captured_at": record.get("captured_at"),
        "recorded_at": timestamp,
        "captured_by": record.get("captured_by"),
        "reference": record.get("reference") or None,
        "note": record.get("note") or None,
    }


def payment_summary_from_payment_module(
    order_payment_state: str,
    payment_ref: dict[str, Any],
    payment_record: dict[str, Any],
    timestamp: str,
) -> dict[str, Any]:
    currency = str(payment_record.get("currency") or payment_ref.get("payment_currency") or "").strip().lower() or None
    amount_cents = payment_record.get("amount_cents")
    if amount_cents in (None, ""):
        amount_cents = payment_ref.get("payment_amount_cents")
    return {
        "schema_version": "1.0",
        "visibility_state": "confirmed_in_records",
        "source_kind": "payment_module",
        "record_kind": "payment_module_record",
        "record_id": str(payment_record.get("id") or "") or None,
        "payment_state": order_payment_state,
        "amount_cents": amount_cents,
        "currency": currency,
        "captured_at": str(payment_record.get("updated_at") or "").strip() or timestamp,
        "recorded_at": timestamp,
        "captured_by": "payment_module",
        "reference": str(payment_ref.get("checkout_session_id") or payment_ref.get("payment_link_id") or "").strip() or None,
        "note": None,
        "provider_payment_status": str(payment_ref.get("provider_payment_status") or "").strip() or None,
        "payment_record_status": str(payment_record.get("status") or "").strip() or None,
        "stripe_payment_intent_id": str(payment_record.get("stripe_payment_intent_id") or "").strip() or None,
    }


def normalize_payment_summary(order: dict[str, Any]) -> dict[str, Any]:
    summary = order.get("payment_summary")
    if isinstance(summary, dict) and summary:
        normalized = copy.deepcopy(summary)
        normalized.setdefault("schema_version", "1.0")
        normalized.setdefault("payment_state", str(order.get("payment_state") or "unpaid"))
        normalized.setdefault("visibility_state", "not_yet_visible")
        normalized.setdefault("source_kind", "none")
        normalized.setdefault("record_kind", "none")
        normalized.setdefault("record_id", None)
        normalized.setdefault("amount_cents", None)
        normalized.setdefault("currency", None)
        normalized.setdefault("captured_at", None)
        normalized.setdefault("recorded_at", None)
        normalized.setdefault("captured_by", None)
        normalized.setdefault("reference", None)
        normalized.setdefault("note", None)
        return normalized
    return default_payment_summary(str(order.get("payment_state") or "unpaid"))


def order_index_entry(order: dict[str, Any], timestamp: str | None = None) -> dict[str, Any]:
    summary = normalize_payment_summary(order)
    try:
        from printavo_bridge_common import normalize_printavo_summary  # noqa: PLC0415

        printavo_summary = normalize_printavo_summary(order)
    except Exception:  # pragma: no cover - defensive
        printavo_summary = {
            "printavo_state": "needs_more_info_before_printavo",
            "source_kind": "none",
            "record_id": None,
        }
    return {
        "order_id": order.get("order_id"),
        "current_revision_id": order.get("current_revision_id"),
        "active_quote_id": order.get("active_quote_id"),
        "customer_id": order.get("customer_id"),
        "customer_email": order.get("customer_email"),
        "customer_name": order.get("customer_name"),
        "lifecycle_state": order.get("lifecycle_state"),
        "payment_state": order.get("payment_state"),
        "payment_visibility_state": summary.get("visibility_state"),
        "payment_source_kind": summary.get("source_kind"),
        "payment_record_id": summary.get("record_id"),
        "printavo_state": printavo_summary.get("printavo_state"),
        "printavo_source_kind": printavo_summary.get("source_kind"),
        "printavo_record_id": printavo_summary.get("record_id"),
        "intake_seed_refs": copy.deepcopy(order.get("intake_seed_refs") or []),
        "source_quote_packet_id": order.get("source_quote_packet_id"),
        "created_at": order.get("created_at"),
        "updated_at": timestamp or order.get("updated_at"),
    }


def payment_capture_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "payment_capture_id": record.get("payment_capture_id"),
        "order_id": record.get("order_id"),
        "quote_id": record.get("quote_id"),
        "customer_id": record.get("customer_id"),
        "customer_email": record.get("customer_email"),
        "customer_name": record.get("customer_name"),
        "source_quote_packet_id": record.get("source_quote_packet_id"),
        "payment_state": record.get("payment_state"),
        "visibility_state": "confirmed_in_records",
        "source_kind": record.get("source_kind"),
        "amount_cents": record.get("amount_cents"),
        "currency": record.get("currency"),
        "captured_at": record.get("captured_at"),
        "recorded_at": record.get("recorded_at"),
        "captured_by": record.get("captured_by"),
        "reference": record.get("reference") or None,
    }


def manual_capture_id(
    *,
    order_id: str,
    quote_id: str,
    payment_state: str,
    amount_cents: int | None,
    currency: str,
    captured_at: str,
    captured_by: str,
    reference: str,
    note: str,
) -> str:
    signature = json.dumps(
        {
            "order_id": order_id,
            "quote_id": quote_id,
            "payment_state": payment_state,
            "amount_cents": amount_cents,
            "currency": currency.upper(),
            "captured_at": captured_at,
            "captured_by": captured_by,
            "reference": reference,
            "note": note,
        },
        sort_keys=True,
    )
    return str(uuid.uuid5(PAYMENT_CAPTURE_NAMESPACE, signature))


def first_iso_desc(value: dict[str, Any], primary_key: str, secondary_key: str = "") -> tuple[str, str]:
    primary = str(value.get(primary_key) or "")
    secondary = str(value.get(secondary_key) or "") if secondary_key else ""
    return (primary, secondary)


def latest_capture_for_order(captures: list[dict[str, Any]], order_id: str) -> dict[str, Any] | None:
    matches = [record for record in captures if str(record.get("order_id") or "") == order_id]
    if not matches:
        return None
    matches.sort(key=lambda item: first_iso_desc(item, "recorded_at", "captured_at"), reverse=True)
    return matches[0]


def load_order(paths: dict[str, Path], order_id: str) -> tuple[Path, dict[str, Any]]:
    path = entity_file(paths["orders_dir"], "order", order_id)
    if not path.exists():
        raise FileNotFoundError(f"canonical order not found: {order_id}")
    payload = load_yaml_object(path)
    if not payload:
        raise ValueError(f"canonical order is not a valid object: {order_id}")
    return path, payload


def load_quote(paths: dict[str, Path], quote_id: str) -> tuple[Path, dict[str, Any]]:
    path = entity_file(paths["quotes_dir"], "quote", quote_id)
    if not path.exists():
        raise FileNotFoundError(f"canonical quote not found: {quote_id}")
    payload = load_yaml_object(path)
    if not payload:
        raise ValueError(f"canonical quote is not a valid object: {quote_id}")
    return path, payload


def resolve_order_context(paths: dict[str, Path], *, order_id: str = "", quote_id: str = "") -> tuple[Path, dict[str, Any], dict[str, Any] | None]:
    normalized_order_id = str(order_id or "").strip()
    normalized_quote_id = str(quote_id or "").strip()
    quote: dict[str, Any] | None = None
    if normalized_quote_id:
        _quote_file, quote = load_quote(paths, normalized_quote_id)
        normalized_order_id = str(quote.get("order_id") or "").strip()
        if not normalized_order_id:
            raise ValueError("canonical quote is missing order_id")
    if not normalized_order_id:
        raise ValueError("either order_id or quote_id is required")
    order_file, order = load_order(paths, normalized_order_id)
    if quote is None:
        active_quote_id = str(order.get("active_quote_id") or "").strip()
        if active_quote_id:
            try:
                _quote_file, quote = load_quote(paths, active_quote_id)
            except FileNotFoundError:
                quote = None
    return order_file, order, quote


def sync_order_payment_projection(
    paths: dict[str, Path],
    order_file: Path,
    order: dict[str, Any],
    summary: dict[str, Any],
    *,
    lifecycle_override: str | None = None,
) -> None:
    timestamp = str(summary.get("recorded_at") or now_utc())
    order["payment_state"] = str(summary.get("payment_state") or order.get("payment_state") or "unpaid")
    order["payment_summary"] = copy.deepcopy(summary)
    if lifecycle_override:
        order["lifecycle_state"] = lifecycle_override
    order["updated_at"] = timestamp
    dump_yaml(order_file, order)
    update_entity_index(paths["orders_index_file"], "orders", "order_id", order_index_entry(order, timestamp))
