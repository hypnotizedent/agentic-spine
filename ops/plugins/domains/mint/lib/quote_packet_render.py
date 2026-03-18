#!/usr/bin/env python3
"""Render review-ready quote drafts directly from governed quote_packet state."""

from __future__ import annotations

import argparse
import copy
import os
import sys
from pathlib import Path
from typing import Any

from customer_mail_identity_common import project_mail_identity, salutation_text, validate_mail_identity_projection
from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root
from quote_packet_normalize import append_receipt, dump_yaml, fail, load_structured_file, now_utc, sync_quote_readiness


BLOCKED_PRICING_STATES = {
    "blocked_insufficient_inputs",
    "service_unavailable",
    "api_key_unavailable",
    "api_call_failed",
    "not_requested",
}
TERMINAL_STATES = {"sent", "paid", "closed"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-render",
        description="Render a review-ready quote draft from persisted quote_packet state.",
    )
    parser.add_argument("packet_id", help="quote_packet_id to render")
    return parser.parse_args(argv)


def as_number(value: Any) -> float:
    if value in (None, ""):
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value))
    except ValueError:
        return 0.0


def format_money(value: Any) -> str:
    return f"${as_number(value):,.2f}"


def humanize_token(value: str) -> str:
    return value.replace("_", " ").replace("-", " ").strip()


def size_breakdown_summary(value: Any) -> str:
    if isinstance(value, dict):
        parts = [f"{size}:{qty}" for size, qty in value.items()]
        return ", ".join(parts)
    if value in (None, ""):
        return ""
    return str(value)


def line_price_map(packet: dict[str, Any]) -> dict[str, dict[str, Any]]:
    pricing_snapshot = packet.get("pricing_snapshot") or {}
    price_entries = pricing_snapshot.get("line_item_prices") or []
    line_items = packet.get("line_items") or []
    mapped: dict[str, dict[str, Any]] = {}
    for idx, entry in enumerate(price_entries):
        if not isinstance(entry, dict):
            continue
        line_item_id = entry.get("line_item_id")
        if not line_item_id and idx < len(line_items):
            line_item_id = line_items[idx].get("line_item_id")
        if line_item_id:
            mapped[str(line_item_id)] = entry
    return mapped


def shipping_posture(packet: dict[str, Any]) -> dict[str, str]:
    warning_gap = next(
        (
            gap
            for gap in packet.get("open_gaps") or []
            if gap.get("gap_type") == "shipping_ambiguity" and gap.get("severity") == "warning"
        ),
        None,
    )
    shipping_total = as_number(((packet.get("pricing_snapshot") or {}).get("calculated_totals") or {}).get("shipping"))
    if warning_gap:
        return {
            "state": "pending",
            "summary": str(warning_gap.get("description") or "Shipping is pending and excluded from the current quote total."),
            "customer_summary": "Shipping is not included in this draft total and will be finalized separately.",
        }
    if shipping_total > 0:
        return {
            "state": "included",
            "summary": f"Shipping is included in the current total at {format_money(shipping_total)}.",
            "customer_summary": f"Shipping is included in the current total at {format_money(shipping_total)}.",
        }
    return {
        "state": "included_zero",
        "summary": "Shipping currently prices at $0.00 in the packet snapshot.",
        "customer_summary": "Shipping currently prices at $0.00 in this draft.",
    }


def line_entries(packet: dict[str, Any]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    prices = line_price_map(packet)
    for item in packet.get("line_items") or []:
        if not isinstance(item, dict):
            continue
        description = str(item.get("description") or humanize_token(str(item.get("product_type") or "line item")).title())
        entry: dict[str, Any] = {
            "line_item_id": item.get("line_item_id"),
            "description": description,
            "quantity": item.get("quantity"),
        }

        decoration_parts: list[str] = []
        if item.get("decoration_method"):
            decoration_parts.append(humanize_token(str(item["decoration_method"])).title())
        print_locations = item.get("print_locations") or ([] if not item.get("placement") else [item["placement"]])
        if print_locations:
            decoration_parts.append(", ".join(str(location) for location in print_locations))
        if item.get("color_count") is not None:
            color_count = int(item["color_count"])
            decoration_parts.append(f"{color_count} color" if color_count == 1 else f"{color_count} colors")
        if decoration_parts:
            entry["decoration_summary"] = " | ".join(decoration_parts)

        size_summary = size_breakdown_summary(item.get("size_breakdown"))
        if size_summary:
            entry["size_breakdown"] = size_summary

        price_entry = prices.get(str(item.get("line_item_id")))
        if price_entry:
            if price_entry.get("unit_price") is not None:
                entry["unit_price"] = price_entry["unit_price"]
            elif price_entry.get("unit_price_cents") is not None:
                entry["unit_price"] = round(as_number(price_entry["unit_price_cents"]) / 100, 2)
            if price_entry.get("line_total") is not None:
                entry["line_total"] = price_entry["line_total"]
            elif price_entry.get("total") is not None:
                entry["line_total"] = price_entry["total"]
            elif price_entry.get("line_total_cents") is not None:
                entry["line_total"] = round(as_number(price_entry["line_total_cents"]) / 100, 2)
        entries.append(entry)
    return entries


def warning_notes(packet: dict[str, Any]) -> list[str]:
    notes: list[str] = []
    for gap in packet.get("open_gaps") or []:
        if gap.get("severity") == "warning" and gap.get("description"):
            notes.append(str(gap["description"]))
    return notes


def review_ready(packet: dict[str, Any]) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    state = str(packet.get("state") or "")
    if state in TERMINAL_STATES:
        reasons.append(f"packet is already in terminal state {state}")

    if not (packet.get("line_items") or []):
        reasons.append("packet has no line items")

    customer_ref = packet.get("customer_ref") or {}
    if customer_ref.get("identity_state") != "resolved":
        reasons.append("customer identity is not resolved")
    else:
        identity_reasons = validate_mail_identity_projection(project_mail_identity(customer_ref=customer_ref))
        reasons.extend(f"customer mail identity invalid: {reason}" for reason in identity_reasons)

    blocking_gaps = [gap for gap in packet.get("open_gaps") or [] if gap.get("severity") == "blocking"]
    if blocking_gaps:
        reasons.append(f"packet has {len(blocking_gaps)} blocking gaps")

    pricing_snapshot = packet.get("pricing_snapshot")
    if not isinstance(pricing_snapshot, dict):
        reasons.append("pricing_snapshot is missing")
    else:
        pricing_state = str(pricing_snapshot.get("pricing_state") or "")
        if pricing_state in BLOCKED_PRICING_STATES:
            reasons.append(f"pricing is not complete ({pricing_state})")
        confidence = str(pricing_snapshot.get("confidence_level") or "none")
        if confidence not in {"medium", "high"}:
            reasons.append(f"pricing confidence must be medium or high (found {confidence})")

    return (not reasons), reasons


def draft_payload(packet: dict[str, Any], timestamp: str) -> dict[str, Any]:
    pricing_snapshot = packet.get("pricing_snapshot") or {}
    totals = copy.deepcopy(pricing_snapshot.get("calculated_totals") or {"subtotal": 0, "tax": 0, "shipping": 0, "total": 0})
    customer_ref = packet.get("customer_ref") or {}
    projection = project_mail_identity(customer_ref=customer_ref)
    customer_display_name = (
        customer_ref.get("resolved_name")
        or customer_ref.get("customer_query")
        or customer_ref.get("customer_id")
        or "Customer"
    )
    customer_salutation = salutation_text(projection, named_prefix="Hi")
    shipping = shipping_posture(packet)

    return {
        "quote_packet_id": packet.get("quote_packet_id"),
        "title": f"Quote Draft for {customer_display_name}",
        "customer_display_name": customer_display_name,
        "customer_salutation": customer_salutation,
        "generated_at": timestamp,
        "line_items": line_entries(packet),
        "totals": totals,
        "shipping_posture": shipping,
        "warning_notes": warning_notes(packet),
    }


def message_draft(payload: dict[str, Any]) -> str:
    lines: list[str] = []
    for item in payload.get("line_items") or []:
        quantity = item.get("quantity")
        description = item.get("description") or "Line item"
        summary = f"- {quantity} x {description}" if quantity not in (None, "") else f"- {description}"
        if item.get("decoration_summary"):
            summary += f" ({item['decoration_summary']})"
        if item.get("line_total") is not None:
            summary += f" — {format_money(item['line_total'])}"
        lines.append(summary)

    if not lines:
        lines.append("- Quote details pending")

    totals = payload.get("totals") or {}
    warnings = payload.get("warning_notes") or []
    shipping = payload.get("shipping_posture") or {}
    customer_salutation = payload.get("customer_salutation") or "Hello,"

    body = [
        customer_salutation,
        "",
        "I put together your quote draft for review:",
        *lines,
        "",
        f"Subtotal: {format_money(totals.get('subtotal'))}",
    ]
    tax_total = as_number(totals.get("tax"))
    if tax_total:
        body.append(f"Tax: {format_money(tax_total)}")
    body.append(f"Shipping: {shipping.get('customer_summary') or shipping.get('summary')}")
    body.append(f"Total: {format_money(totals.get('total'))}")

    if warnings:
        body.extend(["", "Notes:"])
        body.extend(f"- {note}" for note in warnings)

    body.extend(
        [
            "",
            "If everything looks right, let me know and I will keep it moving through final review.",
            "",
            "Thanks,",
            "Ronny",
        ]
    )
    return "\n".join(body)


def clear_stale_payment_ref(packet: dict[str, Any]) -> bool:
    payment_ref = packet.get("payment_ref")
    if not isinstance(payment_ref, dict):
        return False

    payment_url = str(payment_ref.get("payment_link_url") or "")
    payment_state = str(payment_ref.get("payment_link_state") or "")
    blocking_reason = str(payment_ref.get("blocking_reason") or "")
    if (
        "PLACEHOLDER" in payment_url
        or payment_state == "blocked_requires_order_id"
        or "quote-to-payment bridge not yet implemented" in blocking_reason
        or "requires canonical order/quote truth" in blocking_reason
    ):
        packet.pop("payment_ref", None)
        return True
    return False


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    spine_root = resolve_spine_root(__file__)
    mint_root = resolve_mint_data_root(spine_root=spine_root, current_file=__file__)
    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (mint_root / "quote-packets"))
    packet_file = packets_dir / f"quote_packet_{args.packet_id}.yaml"
    if not packet_file.exists():
        fail(f"packet not found: {args.packet_id}")

    packet = load_structured_file(packet_file) or {}
    renderable, reasons = review_ready(packet)
    if not renderable:
        fail("cannot render: " + "; ".join(reasons))

    timestamp = now_utc()
    payload = draft_payload(packet, timestamp)
    packet["quote_draft_ref"] = {
        "draft_type": "inline",
        "draft_payload": payload,
        "generated_at": timestamp,
    }
    packet["customer_message_draft"] = message_draft(payload)
    packet["updated_at"] = timestamp

    cleared_payment = clear_stale_payment_ref(packet)
    receipts = append_receipt(packet.get("receipts") or [], "mint.quote.render", timestamp)
    packet["receipts"] = receipts

    current_state = str(packet.get("state") or "")
    packet["state"] = current_state if current_state == "approved_to_send" else "ready_for_review"
    readiness = sync_quote_readiness(packet)

    dump_yaml(packet_file, packet)

    print(f"quote_packet_id: {args.packet_id}")
    print(f"state: {current_state} -> {packet['state']}")
    print(f"quote_readiness_state: {readiness['state']}")
    print(f"quote_next_step: {readiness['next_step']}")
    print("render_status: success")
    print("quote_draft: generated")
    print("customer_message: generated")
    print(f"shipping_posture: {payload['shipping_posture']['state']}")
    print(f"warning_count: {len(payload['warning_notes'])}")
    print(f"payment_ref_cleared: {str(cleared_payment).lower()}")
    print(f"packet_file: {packet_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
