#!/usr/bin/env python3
"""Promote approved quote_packet work objects into canonical order truth records."""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys
import uuid
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root
from payment_record_common import default_payment_summary, order_index_entry
from printavo_bridge_common import default_printavo_summary
from quote_packet_normalize import (
    append_receipt,
    dump_yaml,
    fail,
    load_structured_file,
    now_utc,
    pricing_missing_fields,
    sync_quote_readiness,
    update_index,
)


PROMOTION_NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, "https://spine.ronny.works/mint/quote-promote")
TERMINAL_PACKET_STATES = {"sent", "paid", "closed"}
VALID_PROMOTION_PACKET_STATES = {"approved_to_send"}
ALLOWED_QUOTE_STATES = {"draft", "sent", "accepted", "rejected", "expired", "superseded"}
ALLOWED_ORDER_STATES = {"draft", "quoted", "approved", "production", "fulfilled", "cancelled"}
ALLOWED_PAYMENT_STATES = {"unpaid", "partially_paid", "paid", "refunded"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-promote",
        description="Promote an approved quote_packet into canonical order/revision/quote runtime records.",
    )
    parser.add_argument("packet_id", help="quote_packet_id to promote")
    parser.add_argument(
        "--approved-by",
        help="Explicit operator approval identity for this promotion (defaults to packet operator_approval.approved_by when present)",
    )
    parser.add_argument("--approval-note", help="Optional approval note for audit lineage")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.promote"


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


def packet_file_for_id(packets_dir: Path, packet_id: str) -> Path:
    return packets_dir / f"quote_packet_{packet_id}.yaml"


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


def deterministic_uuid(packet_id: str, entity_kind: str) -> str:
    return str(uuid.uuid5(PROMOTION_NAMESPACE, f"{packet_id}:{entity_kind}"))


def artwork_binding_uuid(packet_id: str, binding: dict[str, Any], index: int) -> str:
    signature = json.dumps(
        {
            "line_item_id": binding.get("line_item_id"),
            "seed_refs": binding.get("seed_refs") or [],
            "asset_refs": binding.get("asset_refs") or [],
            "artwork_job_refs": binding.get("artwork_job_refs") or [],
            "binding_state": binding.get("binding_state") or "unmapped",
            "index": index,
        },
        sort_keys=True,
    )
    return str(uuid.uuid5(PROMOTION_NAMESPACE, f"{packet_id}:artwork-binding:{signature}"))


def as_decimal(value: Any) -> Decimal:
    if value in (None, ""):
        return Decimal("0.00")
    try:
        return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except Exception:  # pragma: no cover - defensive
        return Decimal("0.00")


def money_to_cents(value: Any) -> int:
    return int((as_decimal(value) * 100).to_integral_value(rounding=ROUND_HALF_UP))


def integer_or_none(value: Any) -> int | None:
    if value in (None, ""):
        return None
    try:
        return int(value)
    except Exception:  # pragma: no cover - defensive
        return None


def seed_refs_from_packet(packet: dict[str, Any]) -> list[str]:
    seed_refs: list[str] = []
    for ref in packet.get("source_refs") or []:
        if not isinstance(ref, dict):
            continue
        seed_id = str(ref.get("seed_id") or "").strip()
        if seed_id and seed_id not in seed_refs:
            seed_refs.append(seed_id)
    for binding in packet.get("artwork_bindings") or []:
        if not isinstance(binding, dict):
            continue
        for seed_id in binding.get("seed_refs") or []:
            token = str(seed_id or "").strip()
            if token and token not in seed_refs:
                seed_refs.append(token)
    return seed_refs


def packet_blocking_reasons(packet: dict[str, Any]) -> list[str]:
    reasons: list[str] = []
    state = str(packet.get("state") or "")
    if state not in VALID_PROMOTION_PACKET_STATES:
        reasons.append(f"packet state is {state} (must be approved_to_send)")

    if state in TERMINAL_PACKET_STATES and not all(packet.get(field) for field in ("order_id", "order_revision_id", "quote_id")):
        reasons.append(f"packet is already in terminal state {state} without canonical promotion refs")

    customer_ref = packet.get("customer_ref") or {}
    if customer_ref.get("identity_state") != "resolved":
        reasons.append("customer identity is not resolved")
    if not customer_ref.get("customer_id"):
        reasons.append("customer_id is missing from resolved customer_ref")
    if not customer_ref.get("resolved_email"):
        reasons.append("resolved customer email is required before quote promotion")

    blocking_gaps = [gap for gap in packet.get("open_gaps") or [] if isinstance(gap, dict) and gap.get("severity") == "blocking"]
    if blocking_gaps:
        reasons.append(f"packet has {len(blocking_gaps)} blocking gaps")

    line_items = [item for item in packet.get("line_items") or [] if isinstance(item, dict)]
    if not line_items:
        reasons.append("packet has no line_items to promote")
    for item in line_items:
        missing = pricing_missing_fields(item)
        if missing:
            label = str(item.get("description") or item.get("product_type") or item.get("line_item_id") or "line item")
            reasons.append(f"line item is not quote_ready for {label}: {', '.join(missing)}")

    pricing_snapshot = packet.get("pricing_snapshot")
    if not isinstance(pricing_snapshot, dict):
        reasons.append("pricing_snapshot is missing")
    else:
        if pricing_snapshot.get("pricing_state") != "completed":
            reasons.append(f"pricing_snapshot is not completed ({pricing_snapshot.get('pricing_state') or 'unknown'})")
        if pricing_snapshot.get("confidence_level") not in {"medium", "high"}:
            reasons.append(
                f"pricing_snapshot confidence must be medium or high (found {pricing_snapshot.get('confidence_level') or 'none'})"
            )
        if not pricing_snapshot.get("pricing_snapshot_id"):
            reasons.append("pricing_snapshot_id is missing")

    if not isinstance(packet.get("quote_draft_ref"), dict):
        reasons.append("quote_draft_ref is missing")
    if not str(packet.get("customer_message_draft") or "").strip():
        reasons.append("customer_message_draft is missing")

    if not seed_refs_from_packet(packet):
        reasons.append("packet has no intake seed reference to promote")

    return reasons


def require_consistent_existing_refs(packet: dict[str, Any], packet_id: str) -> tuple[str, str, str]:
    existing_order_id = str(packet.get("order_id") or "").strip()
    existing_revision_id = str(packet.get("order_revision_id") or "").strip()
    existing_quote_id = str(packet.get("quote_id") or "").strip()

    present = [bool(existing_order_id), bool(existing_revision_id), bool(existing_quote_id)]
    if any(present) and not all(present):
        fail("packet promotion refs are partial; expected order_id, order_revision_id, and quote_id together")

    if all(present):
        return existing_order_id, existing_revision_id, existing_quote_id

    return (
        deterministic_uuid(packet_id, "order"),
        deterministic_uuid(packet_id, "order-revision:1"),
        deterministic_uuid(packet_id, "quote"),
    )


def resolve_operator_approval(packet: dict[str, Any], args: argparse.Namespace, timestamp: str) -> tuple[str, str, dict[str, Any]]:
    existing = copy.deepcopy(packet.get("operator_approval") or {})
    existing_by = str(existing.get("approved_by") or "").strip()
    existing_note = str(existing.get("approval_note") or "").strip()
    existing_at = str(existing.get("approved_at") or "").strip()

    approved_by = str(args.approved_by or existing_by).strip()
    if not approved_by:
        fail("operator approval identity missing; run mint.quote.approve or pass --approved-by")
    if existing_by and args.approved_by and approved_by != existing_by:
        fail(f"packet operator_approval is already bound to {existing_by}; refusing conflicting --approved-by {args.approved_by}")

    approval_note = str(args.approval_note or existing_note).strip()
    approved_at = existing_at or timestamp
    record = {
        "status": "approved",
        "approved_by": approved_by,
        "approved_at": approved_at,
        "approval_note": approval_note,
        "approval_source": str(existing.get("approval_source") or "operator_review"),
        "source_capability": str(existing.get("source_capability") or current_capability_name()),
    }
    return approved_by, approval_note, record


def delivery_commitment(packet: dict[str, Any], line_items: list[dict[str, Any]]) -> dict[str, Any]:
    shipping_gap = next(
        (
            gap
            for gap in packet.get("open_gaps") or []
            if isinstance(gap, dict) and gap.get("gap_type") == "shipping_ambiguity"
        ),
        None,
    )
    lead_time_days = [int(item["lead_time_days"]) for item in line_items if integer_or_none(item.get("lead_time_days")) is not None]
    totals = ((packet.get("pricing_snapshot") or {}).get("calculated_totals") or {})
    shipping_total = as_decimal(totals.get("shipping"))

    commitment: dict[str, Any] = {
        "commitment_state": "shipping_pending" if shipping_gap else "quoted",
        "shipping_included": shipping_total > Decimal("0.00"),
        "shipping_total": float(shipping_total),
        "source_quote_packet_id": packet.get("quote_packet_id"),
    }
    if lead_time_days:
        commitment["lead_time_days_max"] = max(lead_time_days)
    if shipping_gap and shipping_gap.get("description"):
        commitment["notes"] = [str(shipping_gap["description"])]
    return commitment


def promoted_artwork_bindings(packet: dict[str, Any], order_revision_id: str) -> tuple[list[dict[str, Any]], dict[str, str]]:
    records: list[dict[str, Any]] = []
    line_binding_map: dict[str, str] = {}
    for idx, binding in enumerate(packet.get("artwork_bindings") or [], start=1):
        if not isinstance(binding, dict) or not binding.get("line_item_id"):
            continue
        artwork_binding_id = artwork_binding_uuid(str(packet.get("quote_packet_id") or ""), binding, idx)
        record = {
            "artwork_binding_id": artwork_binding_id,
            "order_revision_id": order_revision_id,
            "order_line_id": binding["line_item_id"],
            "binding_scope": "order_line",
            "seed_refs": copy.deepcopy(binding.get("seed_refs") or []),
            "asset_refs": copy.deepcopy(binding.get("asset_refs") or []),
            "artwork_job_refs": copy.deepcopy(binding.get("artwork_job_refs") or []),
            "selection_state": binding.get("binding_state") or "unmapped",
            "created_at": now_utc(),
            "source_quote_packet_id": packet.get("quote_packet_id"),
        }
        records.append(record)
        line_binding_map[str(binding["line_item_id"])] = artwork_binding_id
    return records, line_binding_map


def promoted_line_items(
    packet: dict[str, Any], pricing_snapshot_id: str, artwork_binding_map: dict[str, str]
) -> list[dict[str, Any]]:
    promoted: list[dict[str, Any]] = []
    for item in packet.get("line_items") or []:
        if not isinstance(item, dict):
            continue
        line = copy.deepcopy(item)
        order_line_id = str(line.pop("line_item_id"))
        line["order_line_id"] = order_line_id
        line["pricing_snapshot_id"] = pricing_snapshot_id
        if order_line_id in artwork_binding_map:
            line["artwork_binding_ref"] = artwork_binding_map[order_line_id]
        promoted.append(line)
    return promoted


def build_pricing_snapshot_record(packet: dict[str, Any], order_revision_id: str) -> dict[str, Any]:
    pricing_snapshot = copy.deepcopy(packet.get("pricing_snapshot") or {})
    line_items = [item for item in packet.get("line_items") or [] if isinstance(item, dict)]
    supplier_inputs = []
    decoration_inputs = []
    for item in line_items:
        order_line_id = str(item.get("line_item_id"))
        supplier_inputs.append(
            {
                "order_line_id": order_line_id,
                "supplier_code": item.get("supplier_code"),
                "supplier_sku": item.get("supplier_sku"),
                "style_code": item.get("style_code"),
                "brand": item.get("brand"),
                "color": item.get("color"),
                "supplier_source": item.get("supplier_source"),
                "blanks_cost_cents": item.get("blanks_cost_cents"),
                "lead_time_days": item.get("lead_time_days"),
                "inventory_as_of_utc": item.get("inventory_as_of_utc"),
            }
        )
        decoration_inputs.append(
            {
                "order_line_id": order_line_id,
                "product_type": item.get("product_type"),
                "quantity": item.get("quantity"),
                "decoration_method": item.get("decoration_method"),
                "color_count": item.get("color_count"),
                "print_locations": copy.deepcopy(item.get("print_locations") or []),
                "graphic_size_inches": copy.deepcopy(item.get("graphic_size_inches")),
                "size_tier_label": item.get("size_tier_label"),
                "setup_mode": item.get("setup_mode"),
                "method_variant": item.get("method_variant"),
                "underbase_needed": item.get("underbase_needed"),
                "stitch_count": item.get("stitch_count"),
                "puff_mode": item.get("puff_mode"),
                "thread_type": item.get("thread_type"),
                "hoop_class": item.get("hoop_class"),
                "garment_material": item.get("garment_material"),
                "curved_panel_cap": item.get("curved_panel_cap"),
                "material_class": item.get("material_class"),
                "transfer_type": item.get("transfer_type"),
                "artwork_fingerprint_sha256": item.get("artwork_fingerprint_sha256"),
                "garment_family": item.get("garment_family"),
            }
        )

    return {
        "pricing_snapshot_id": pricing_snapshot["pricing_snapshot_id"],
        "order_revision_id": order_revision_id,
        "supplier_inputs": supplier_inputs,
        "decoration_inputs": decoration_inputs,
        "pricing_policy_ref": pricing_snapshot.get("pricing_authority_path") or "quote_packet_pricing_snapshot",
        "calculated_totals": copy.deepcopy(pricing_snapshot.get("calculated_totals") or {}),
        "source_revision_markers": {
            "quote_packet_id": packet.get("quote_packet_id"),
            "quote_packet_updated_at": packet.get("updated_at"),
            "packet_pricing_snapshot_id": pricing_snapshot.get("pricing_snapshot_id"),
            "pricing_receipt_refs": copy.deepcopy(pricing_snapshot.get("pricing_receipt_refs") or []),
        },
        "promotion_snapshot": pricing_snapshot,
        "created_at": now_utc(),
        "source_quote_packet_id": packet.get("quote_packet_id"),
    }


def quote_amount_cents(packet: dict[str, Any]) -> int:
    totals = ((packet.get("pricing_snapshot") or {}).get("calculated_totals") or {})
    return money_to_cents(totals.get("total"))


def load_existing_or_none(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    loaded = load_structured_file(path)
    return loaded if isinstance(loaded, dict) else None


def update_entity_index(index_file: Path, list_key: str, entity_key: str, entry: dict[str, Any]) -> None:
    index_data = load_existing_or_none(index_file) or {list_key: []}
    entries = index_data.setdefault(list_key, [])
    existing = next((item for item in entries if item.get(entity_key) == entry.get(entity_key)), None)
    if existing:
        existing.update(copy.deepcopy(entry))
    else:
        entries.append(copy.deepcopy(entry))
    dump_yaml(index_file, index_data)


def print_existing_summary(
    packet: dict[str, Any],
    order_id: str,
    order_revision_id: str,
    quote_id: str,
    packets_dir: Path,
    order_dir: Path,
    order_revisions_dir: Path,
    quotes_dir: Path,
    pricing_snapshots_dir: Path,
) -> int:
    pricing_snapshot_id = str((packet.get("pricing_snapshot") or {}).get("pricing_snapshot_id") or "")
    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print("promotion_state: existing")
    print(f"state: {packet['state']}")
    print(f"order_id: {order_id}")
    print(f"order_revision_id: {order_revision_id}")
    print(f"quote_id: {quote_id}")
    print(f"pricing_snapshot_id: {pricing_snapshot_id}")
    print(f"order_file: {entity_file(order_dir, 'order', order_id)}")
    print(f"order_revision_file: {entity_file(order_revisions_dir, 'order_revision', order_revision_id)}")
    print(f"quote_file: {entity_file(quotes_dir, 'quote', quote_id)}")
    if pricing_snapshot_id:
        print(f"pricing_snapshot_file: {entity_file(pricing_snapshots_dir, 'pricing_snapshot', pricing_snapshot_id)}")
    print(f"packet_file: {packet_file_for_id(packets_dir, packet['quote_packet_id'])}")
    return 0


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    spine_root = resolve_spine_root(__file__)
    mint_root = resolve_mint_data_root(spine_root=spine_root, current_file=__file__)

    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (mint_root / "quote-packets"))
    packet_index_file = Path(os.environ.get("MINT_QUOTE_PACKET_INDEX_FILE") or (mint_root / "quote-packets-index.yaml"))
    orders_dir = Path(os.environ.get("MINT_ORDER_RUNTIME_DIR") or (mint_root / "orders"))
    orders_index_file = Path(os.environ.get("MINT_ORDER_INDEX_FILE") or (mint_root / "orders-index.yaml"))
    order_revisions_dir = Path(os.environ.get("MINT_ORDER_REVISIONS_DIR") or (mint_root / "order-revisions"))
    order_revisions_index_file = Path(os.environ.get("MINT_ORDER_REVISION_INDEX_FILE") or (mint_root / "order-revisions-index.yaml"))
    quotes_dir = Path(os.environ.get("MINT_QUOTES_DIR") or (mint_root / "quotes"))
    quotes_index_file = Path(os.environ.get("MINT_QUOTES_INDEX_FILE") or (mint_root / "quotes-index.yaml"))
    pricing_snapshots_dir = Path(os.environ.get("MINT_PRICING_SNAPSHOTS_DIR") or (mint_root / "pricing-snapshots"))
    pricing_snapshots_index_file = Path(
        os.environ.get("MINT_PRICING_SNAPSHOT_INDEX_FILE") or (mint_root / "pricing-snapshots-index.yaml")
    )
    artwork_bindings_dir = Path(os.environ.get("MINT_ARTWORK_BINDINGS_DIR") or (mint_root / "artwork-bindings"))
    artwork_bindings_index_file = Path(
        os.environ.get("MINT_ARTWORK_BINDINGS_INDEX_FILE") or (mint_root / "artwork-bindings-index.yaml")
    )

    packet_file = packet_file_for_id(packets_dir, args.packet_id)
    if not packet_file.exists():
        fail(f"quote_packet not found: {args.packet_id}")

    packet = load_structured_file(packet_file) or {}
    if not isinstance(packet, dict):
        fail(f"quote_packet is not a valid object: {args.packet_id}")

    order_id, order_revision_id, quote_id = require_consistent_existing_refs(packet, args.packet_id)
    order_file = entity_file(orders_dir, "order", order_id)
    order_revision_file = entity_file(order_revisions_dir, "order_revision", order_revision_id)
    quote_file = entity_file(quotes_dir, "quote", quote_id)
    pricing_snapshot_id = str((packet.get("pricing_snapshot") or {}).get("pricing_snapshot_id") or "")
    pricing_snapshot_file = entity_file(pricing_snapshots_dir, "pricing_snapshot", pricing_snapshot_id) if pricing_snapshot_id else None

    if all(path.exists() for path in (order_file, order_revision_file, quote_file)) and packet.get("order_id") and packet.get("order_revision_id") and packet.get("quote_id"):
        return print_existing_summary(
            packet,
            order_id,
            order_revision_id,
            quote_id,
            packets_dir,
            orders_dir,
            order_revisions_dir,
            quotes_dir,
            pricing_snapshots_dir,
        )

    blocking_reasons = packet_blocking_reasons(packet)
    if blocking_reasons:
        fail(f"cannot promote: {'; '.join(blocking_reasons)}")

    customer_ref = copy.deepcopy(packet.get("customer_ref") or {})
    timestamp = now_utc()
    capability_name = current_capability_name()
    approved_by, approval_note, operator_approval = resolve_operator_approval(packet, args, timestamp)
    line_items = [item for item in packet.get("line_items") or [] if isinstance(item, dict)]
    seed_refs = seed_refs_from_packet(packet)

    artwork_binding_records, artwork_binding_map = promoted_artwork_bindings(packet, order_revision_id)
    promoted_revision_line_items = promoted_line_items(packet, pricing_snapshot_id, artwork_binding_map)
    pricing_snapshot_record = build_pricing_snapshot_record(packet, order_revision_id)

    order_record = {
        "order_id": order_id,
        "current_revision_id": order_revision_id,
        "active_quote_id": quote_id,
        "customer_identity_state": customer_ref.get("identity_state"),
        "customer_id": customer_ref.get("customer_id"),
        "customer_name": customer_ref.get("resolved_name") or customer_ref.get("customer_query"),
        "customer_contact_name": customer_ref.get("contact_name"),
        "customer_greeting_name": customer_ref.get("greeting_name"),
        "mail_salutation_mode": customer_ref.get("mail_salutation_mode"),
        "customer_email": customer_ref.get("resolved_email"),
        "lifecycle_state": "quoted",
        "payment_state": "unpaid",
        "payment_summary": default_payment_summary("unpaid"),
        "printavo_summary": default_printavo_summary(),
        "intake_seed_refs": seed_refs,
        "assignment": approved_by,
        "operator_working_notes": packet.get("operator_notes") or approval_note or "",
        "source_quote_packet_id": packet.get("quote_packet_id"),
        "created_at": timestamp,
        "updated_at": timestamp,
    }

    order_revision_record = {
        "order_revision_id": order_revision_id,
        "order_id": order_id,
        "revision_index": 1,
        "parent_revision_id": None,
        "change_reason": "quote_packet_initial_promotion",
        "line_items": promoted_revision_line_items,
        "delivery_commitment": delivery_commitment(packet, line_items),
        "artwork_binding_refs": [record["artwork_binding_id"] for record in artwork_binding_records],
        "intake_evidence_refs": copy.deepcopy(packet.get("source_refs") or []),
        "created_at": timestamp,
        "source_quote_packet_id": packet.get("quote_packet_id"),
    }

    quote_record = {
        "quote_id": quote_id,
        "order_id": order_id,
        "order_revision_id": order_revision_id,
        "pricing_snapshot_id": pricing_snapshot_id,
        "quote_state": "draft",
        "issued_at": timestamp,
        "customer_id": customer_ref.get("customer_id"),
        "customer_name": customer_ref.get("resolved_name") or customer_ref.get("customer_query"),
        "customer_contact_name": customer_ref.get("contact_name"),
        "customer_greeting_name": customer_ref.get("greeting_name"),
        "mail_salutation_mode": customer_ref.get("mail_salutation_mode"),
        "customer_email": customer_ref.get("resolved_email"),
        "amount_cents": quote_amount_cents(packet),
        "currency": "usd",
        "quote_draft_ref": copy.deepcopy(packet.get("quote_draft_ref") or {}),
        "approval": {
            "approved_by": approved_by,
            "approved_at": str(operator_approval.get("approved_at") or timestamp),
            "approval_note": approval_note,
        },
        "source_quote_packet_id": packet.get("quote_packet_id"),
        "created_at": timestamp,
        "updated_at": timestamp,
    }

    dump_yaml(order_file, order_record)
    dump_yaml(order_revision_file, order_revision_record)
    dump_yaml(quote_file, quote_record)
    if pricing_snapshot_file is not None:
        dump_yaml(pricing_snapshot_file, pricing_snapshot_record)
    for binding_record in artwork_binding_records:
        dump_yaml(
            entity_file(artwork_bindings_dir, "artwork_binding", binding_record["artwork_binding_id"]),
            binding_record,
        )

    packet["order_id"] = order_id
    packet["order_revision_id"] = order_revision_id
    packet["quote_id"] = quote_id
    packet["operator_approval"] = operator_approval
    packet["updated_at"] = timestamp
    packet["receipts"] = append_receipt(packet.get("receipts") or [], capability_name, timestamp)
    for item in packet.get("line_items") or []:
        if not isinstance(item, dict):
            continue
        line_item_id = str(item.get("line_item_id") or "")
        if line_item_id in artwork_binding_map:
            item["artwork_binding_ref"] = artwork_binding_map[line_item_id]
    readiness = sync_quote_readiness(packet)

    dump_yaml(packet_file, packet)
    update_index(packet_index_file, packet, timestamp)
    update_entity_index(
        orders_index_file,
        "orders",
        "order_id",
        order_index_entry(order_record, order_record["updated_at"]),
    )
    update_entity_index(
        order_revisions_index_file,
        "order_revisions",
        "order_revision_id",
        {
            "order_revision_id": order_revision_id,
            "order_id": order_id,
            "revision_index": 1,
            "source_quote_packet_id": packet.get("quote_packet_id"),
            "created_at": timestamp,
        },
    )
    update_entity_index(
        quotes_index_file,
        "quotes",
        "quote_id",
        {
            "quote_id": quote_id,
            "order_id": order_id,
            "order_revision_id": order_revision_id,
            "quote_state": quote_record["quote_state"],
            "source_quote_packet_id": packet.get("quote_packet_id"),
            "created_at": timestamp,
            "updated_at": timestamp,
        },
    )
    if pricing_snapshot_file is not None:
        update_entity_index(
            pricing_snapshots_index_file,
            "pricing_snapshots",
            "pricing_snapshot_id",
            {
                "pricing_snapshot_id": pricing_snapshot_id,
                "order_revision_id": order_revision_id,
                "source_quote_packet_id": packet.get("quote_packet_id"),
                "created_at": timestamp,
            },
        )
    for binding_record in artwork_binding_records:
        update_entity_index(
            artwork_bindings_index_file,
            "artwork_bindings",
            "artwork_binding_id",
            {
                "artwork_binding_id": binding_record["artwork_binding_id"],
                "order_revision_id": order_revision_id,
                "order_line_id": binding_record["order_line_id"],
                "source_quote_packet_id": packet.get("quote_packet_id"),
                "created_at": binding_record["created_at"],
            },
        )

    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print("promotion_state: promoted")
    print(f"state: {packet['state']}")
    print(f"quote_readiness_state: {readiness['state']}")
    print(f"quote_next_step: {readiness['next_step']}")
    print(f"approved_by: {approved_by}")
    print(f"order_id: {order_id}")
    print(f"order_revision_id: {order_revision_id}")
    print(f"quote_id: {quote_id}")
    print(f"pricing_snapshot_id: {pricing_snapshot_id}")
    print(f"artwork_binding_count: {len(artwork_binding_records)}")
    print(f"order_file: {order_file}")
    print(f"order_revision_file: {order_revision_file}")
    print(f"quote_file: {quote_file}")
    if pricing_snapshot_file is not None:
        print(f"pricing_snapshot_file: {pricing_snapshot_file}")
    print(f"packet_file: {packet_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
