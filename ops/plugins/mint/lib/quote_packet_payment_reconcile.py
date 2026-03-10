#!/usr/bin/env python3
"""Project payment module truth back into canonical Mint quote/order/packet state."""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest

from quote_packet_normalize import append_receipt, dump_yaml, fail, load_structured_file, now_utc, update_index
from quote_packet_payment_link import canonical_payment_base_url, resolve_payment_api_key


VALID_PACKET_STATES = {"sent", "paid"}
VALID_QUOTE_STATES = {"sent", "accepted"}
PAID_RECORD_STATES = {"succeeded"}
NONTERMINAL_RECORD_STATES = {"pending", "processing"}
FAILED_RECORD_STATES = {"failed", "cancelled"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-reconcile-payment",
        description="Reconcile payment module truth back into canonical Mint quote/order/packet state.",
    )
    parser.add_argument("quote_id", help="Canonical quote_id to reconcile")
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=20,
        help="HTTP timeout for payment module reads (default: 20)",
    )
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.reconcile_payment"


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


def packet_file_for_id(packets_dir: Path, packet_id: str) -> Path:
    return packets_dir / f"quote_packet_{packet_id}.yaml"


def payment_ref_value(payload: dict[str, Any]) -> dict[str, Any]:
    value = payload.get("payment_ref")
    return copy.deepcopy(value) if isinstance(value, dict) else {}


def update_entity_index(index_file: Path, list_key: str, entity_key: str, entry: dict[str, Any]) -> None:
    index_data = load_structured_file(index_file) if index_file.exists() else {list_key: []}
    if not isinstance(index_data, dict):
        index_data = {list_key: []}
    entries = index_data.setdefault(list_key, [])
    existing = next((item for item in entries if isinstance(item, dict) and item.get(entity_key) == entry.get(entity_key)), None)
    if existing:
        existing.update(copy.deepcopy(entry))
    else:
        entries.append(copy.deepcopy(entry))
    dump_yaml(index_file, index_data)


def get_json(base_url: str, api_key: str, path: str, timeout_seconds: int) -> dict[str, Any]:
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}{path}",
        headers={
            "Accept": "application/json",
            "X-API-Key": api_key,
        },
        method="GET",
    )
    with urlrequest.urlopen(request, timeout=timeout_seconds) as response:
        body = response.read().decode("utf-8")
    payload = json.loads(body or "{}")
    if not isinstance(payload, dict):
        fail(f"payment service returned a non-object payload for {path}")
    return payload


def quote_reconciliation_blocking_reasons(packet: dict[str, Any], quote: dict[str, Any], order: dict[str, Any]) -> list[str]:
    reasons: list[str] = []

    packet_state = str(packet.get("state") or "")
    if packet_state not in VALID_PACKET_STATES:
        reasons.append(f"packet state is {packet_state} (must be sent or paid)")

    quote_state = str(quote.get("quote_state") or "")
    if quote_state not in VALID_QUOTE_STATES:
        reasons.append(f"quote_state is {quote_state} (must be sent or accepted)")

    if not isinstance(order, dict) or not order:
        reasons.append("canonical order record is missing")
    else:
        if str(order.get("lifecycle_state") or "") == "cancelled":
            reasons.append("order lifecycle_state is cancelled")

    packet_quote_id = str(packet.get("quote_id") or "").strip()
    if packet_quote_id != str(quote.get("quote_id") or "").strip():
        reasons.append("quote_packet quote_id does not match canonical quote")

    packet_order_id = str(packet.get("order_id") or "").strip()
    if packet_order_id != str(quote.get("order_id") or "").strip():
        reasons.append("quote_packet order_id does not match canonical quote")

    payment_ref = payment_ref_value(quote)
    if not payment_ref:
        reasons.append("canonical quote payment_ref is missing")
    else:
        if not str(payment_ref.get("checkout_session_id") or payment_ref.get("payment_link_id") or "").strip():
            reasons.append("quote payment_ref is missing checkout_session_id")

    packet_payment_ref = payment_ref_value(packet)
    if not packet_payment_ref:
        reasons.append("quote_packet payment_ref is missing")
    elif payment_ref:
        packet_session = str(packet_payment_ref.get("checkout_session_id") or packet_payment_ref.get("payment_link_id") or "").strip()
        quote_session = str(payment_ref.get("checkout_session_id") or payment_ref.get("payment_link_id") or "").strip()
        if packet_session != quote_session:
            reasons.append("quote_packet payment_ref checkout_session_id does not match canonical quote")

    if str(quote.get("source_quote_packet_id") or "").strip() != str(packet.get("quote_packet_id") or "").strip():
        reasons.append("canonical quote source_quote_packet_id does not match quote_packet")

    return reasons


def find_matching_payment_record(payments: list[dict[str, Any]], session_id: str) -> dict[str, Any] | None:
    for payment in payments:
        if not isinstance(payment, dict):
            continue
        if str(payment.get("stripe_checkout_session_id") or "").strip() == session_id:
            return copy.deepcopy(payment)
    return None


def derive_payment_link_state(session_status: str, provider_payment_status: str, payment_record_status: str) -> str:
    if payment_record_status == "refunded":
        return "refunded"
    if payment_record_status == "succeeded" and provider_payment_status == "paid":
        return "paid"
    if payment_record_status == "processing":
        return "processing"
    if payment_record_status == "failed":
        return "failed"
    if payment_record_status == "cancelled":
        return "cancelled" if session_status != "expired" else "expired"
    if session_status == "expired":
        return "expired"
    return "generated"


def derive_order_payment_state(payment_ref: dict[str, Any], quote: dict[str, Any], order: dict[str, Any]) -> str:
    current_state = str(order.get("payment_state") or "unpaid")
    if current_state == "paid":
        return "paid"

    payment_type = str(payment_ref.get("payment_type") or "full")
    payment_amount_cents = int(payment_ref.get("payment_amount_cents") or 0)
    quote_amount_cents = int(quote.get("amount_cents") or 0)

    if payment_type in {"full", "balance"}:
        return "paid"
    if payment_amount_cents > 0 and quote_amount_cents > 0 and payment_amount_cents >= quote_amount_cents:
        return "paid"
    return "partially_paid"


def synced_payment_ref(
    base_ref: dict[str, Any],
    session: dict[str, Any],
    payment_record: dict[str, Any] | None,
    payment_link_state: str,
    timestamp: str,
) -> dict[str, Any]:
    synced = copy.deepcopy(base_ref)
    synced["payment_link_state"] = payment_link_state
    synced["provider_checkout_status"] = str(session.get("status") or "")
    synced["provider_payment_status"] = str(session.get("payment_status") or "")
    synced["reconciled_at"] = timestamp

    metadata = session.get("metadata") or {}
    if isinstance(metadata, dict):
        order_id = str(metadata.get("order_id") or "").strip()
        if order_id and not synced.get("order_id"):
            synced["order_id"] = order_id

    if payment_record:
        synced["payment_record_id"] = str(payment_record.get("id") or "")
        synced["payment_record_status"] = str(payment_record.get("status") or "")
        stripe_payment_intent_id = str(payment_record.get("stripe_payment_intent_id") or "").strip()
        if stripe_payment_intent_id:
            synced["stripe_payment_intent_id"] = stripe_payment_intent_id
        payment_record_updated_at = str(payment_record.get("updated_at") or "").strip()
        if payment_record_updated_at:
            synced["payment_record_updated_at"] = payment_record_updated_at

        # Mirror refund metadata when payment record shows refunded status
        if str(payment_record.get("status") or "") == "refunded":
            record_metadata = payment_record.get("metadata") or {}
            if isinstance(record_metadata, dict):
                refund_reason = str(record_metadata.get("refund_reason") or "").strip()
                if refund_reason:
                    synced["refund_reason"] = refund_reason
            synced["refunded_at"] = payment_record_updated_at or timestamp
            # Refund amount is the original payment amount (full refund assumed for v1)
            if synced.get("payment_amount_cents"):
                synced["refund_amount_cents"] = synced["payment_amount_cents"]

    return synced


def print_summary(
    reconciliation_state: str,
    packet: dict[str, Any],
    quote: dict[str, Any],
    order: dict[str, Any],
    payment_ref: dict[str, Any],
    packet_file: Path,
    quote_file: Path,
    order_file: Path,
) -> int:
    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"quote_id: {quote['quote_id']}")
    print(f"order_id: {order['order_id']}")
    print(f"reconciliation_state: {reconciliation_state}")
    print(f"packet_state: {packet.get('state') or ''}")
    print(f"quote_state: {quote.get('quote_state') or ''}")
    print(f"order_payment_state: {order.get('payment_state') or ''}")
    print(f"order_lifecycle_state: {order.get('lifecycle_state') or ''}")
    print(f"payment_link_state: {payment_ref.get('payment_link_state') or ''}")
    print(f"provider_checkout_status: {payment_ref.get('provider_checkout_status') or ''}")
    print(f"provider_payment_status: {payment_ref.get('provider_payment_status') or ''}")
    print(f"payment_record_status: {payment_ref.get('payment_record_status') or ''}")
    if payment_ref.get("stripe_payment_intent_id"):
        print(f"stripe_payment_intent_id: {payment_ref['stripe_payment_intent_id']}")
    if packet.get("paid_at"):
        print(f"paid_at: {packet['paid_at']}")
    if payment_ref.get("refunded_at"):
        print(f"refunded_at: {payment_ref['refunded_at']}")
    if payment_ref.get("refund_amount_cents"):
        print(f"refund_amount_cents: {payment_ref['refund_amount_cents']}")
    if payment_ref.get("refund_reason"):
        print(f"refund_reason: {payment_ref['refund_reason']}")
    if payment_ref.get("operator_review_required"):
        print(f"operator_review_required: {payment_ref['operator_review_required']}")
        print(f"operator_review_reason: {payment_ref.get('operator_review_reason') or ''}")
    print(f"packet_file: {packet_file}")
    print(f"quote_file: {quote_file}")
    print(f"order_file: {order_file}")
    return 0


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    spine_root = Path(os.environ.get("SPINE_ROOT") or script_dir.parent.parent.parent.parent)
    mint_root = spine_root / "runtime/domain-state/mint"

    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (mint_root / "quote-packets"))
    packet_index_file = Path(os.environ.get("MINT_QUOTE_PACKET_INDEX_FILE") or (mint_root / "quote-packets-index.yaml"))
    orders_dir = Path(os.environ.get("MINT_ORDER_RUNTIME_DIR") or (mint_root / "orders"))
    orders_index_file = Path(os.environ.get("MINT_ORDER_INDEX_FILE") or (mint_root / "orders-index.yaml"))
    quotes_dir = Path(os.environ.get("MINT_QUOTES_DIR") or (mint_root / "quotes"))
    quotes_index_file = Path(os.environ.get("MINT_QUOTES_INDEX_FILE") or (mint_root / "quotes-index.yaml"))

    quote_file = entity_file(quotes_dir, "quote", args.quote_id)
    if not quote_file.exists():
        fail(f"canonical quote not found: {args.quote_id}")

    quote = load_structured_file(quote_file) or {}
    if not isinstance(quote, dict):
        fail(f"quote is not a valid object: {args.quote_id}")

    order_id = str(quote.get("order_id") or "").strip()
    if not order_id:
        fail("canonical quote is missing order_id")

    order_file = entity_file(orders_dir, "order", order_id)
    if not order_file.exists():
        fail(f"canonical order not found: {order_id}")
    order = load_structured_file(order_file) or {}
    if not isinstance(order, dict):
        fail(f"order is not a valid object: {order_id}")

    packet_id = str(quote.get("source_quote_packet_id") or "").strip()
    if not packet_id:
        fail("canonical quote is missing source_quote_packet_id")
    packet_file = packet_file_for_id(packets_dir, packet_id)
    if not packet_file.exists():
        fail(f"quote_packet not found: {packet_id}")
    packet = load_structured_file(packet_file) or {}
    if not isinstance(packet, dict):
        fail(f"quote_packet is not a valid object: {packet_id}")

    blocking_reasons = quote_reconciliation_blocking_reasons(packet, quote, order)
    if blocking_reasons:
        fail("cannot reconcile payment: " + "; ".join(blocking_reasons))

    api_key = resolve_payment_api_key(spine_root)
    if not api_key:
        fail("PAYMENT_API_KEY is unavailable for governed payment reconciliation")
    base_url = canonical_payment_base_url(spine_root)

    quote_payment_ref = payment_ref_value(quote)
    checkout_session_id = str(
        quote_payment_ref.get("checkout_session_id") or quote_payment_ref.get("payment_link_id") or ""
    ).strip()

    try:
        session = get_json(base_url, api_key, f"/api/v1/payments/checkout-session/{checkout_session_id}", args.timeout_seconds)
        payments_payload = get_json(base_url, api_key, f"/api/orders/{order_id}/payments", args.timeout_seconds)
    except urlerror.HTTPError as exc:
        payload = exc.read().decode("utf-8") if exc.fp else ""
        try:
            details = json.loads(payload or "{}")
        except json.JSONDecodeError:
            details = {}
        message = details.get("error") if isinstance(details, dict) else ""
        if exc.code in {401, 403}:
            fail(f"payment service rejected the configured API key (HTTP {exc.code})")
        if exc.code == 404:
            fail(f"payment service returned HTTP 404: {message or 'payment record not found'}")
        fail(f"payment service returned HTTP {exc.code}: {message or 'payment reconciliation failed'}")
    except urlerror.URLError as exc:
        fail(f"payment service unavailable: {exc.reason}")

    payments = payments_payload.get("payments") or []
    if not isinstance(payments, list):
        fail("payment service returned an invalid payments list")

    session_order_id = str(((session.get("metadata") or {}) if isinstance(session.get("metadata"), dict) else {}).get("order_id") or "").strip()
    if session_order_id and session_order_id != order_id:
        fail("checkout session metadata order_id does not match canonical quote/order truth")

    payment_record = find_matching_payment_record(payments, checkout_session_id)
    provider_checkout_status = str(session.get("status") or "")
    provider_payment_status = str(session.get("payment_status") or "")

    if payment_record is None:
        fail("payment module order history does not contain a record for the generated checkout session")

    payment_record_status = str(payment_record.get("status") or "")
    payment_link_state = derive_payment_link_state(provider_checkout_status, provider_payment_status, payment_record_status)
    timestamp = now_utc()
    synced_ref = synced_payment_ref(quote_payment_ref, session, payment_record, payment_link_state, timestamp)

    packet["payment_ref"] = copy.deepcopy(synced_ref)
    quote["payment_ref"] = copy.deepcopy(synced_ref)
    packet["updated_at"] = timestamp
    packet["receipts"] = append_receipt(packet.get("receipts") or [], current_capability_name(), timestamp)
    quote["updated_at"] = timestamp

    reconciliation_state = "pending"

    if payment_record_status in NONTERMINAL_RECORD_STATES:
        reconciliation_state = "pending_reconciliation" if provider_payment_status == "paid" else "pending"
    elif payment_record_status in FAILED_RECORD_STATES:
        reconciliation_state = "expired" if payment_link_state == "expired" else payment_record_status
    elif payment_record_status == "refunded":
        # Refund projection: mirror refund truth into canonical order/quote/packet WITHOUT automatic lifecycle rollback
        current_lifecycle = str(order.get("lifecycle_state") or "")
        already_refunded = str(order.get("payment_state") or "") == "refunded"

        # Project order.payment_state = refunded (preserves lifecycle_state)
        order["payment_state"] = "refunded"
        order["updated_at"] = timestamp

        # Add operator review flag if order is in production/fulfilled (manual business decision required)
        if current_lifecycle in {"production", "fulfilled"}:
            synced_ref["operator_review_required"] = True
            synced_ref["operator_review_reason"] = f"refund detected on {current_lifecycle} order"
            # Re-sync packet and quote payment_ref after adding operator review fields
            packet["payment_ref"] = copy.deepcopy(synced_ref)
            quote["payment_ref"] = copy.deepcopy(synced_ref)

        # Do NOT mutate: order.lifecycle_state, quote.quote_state, quote_packet.state
        # Refund does not mean quote was rejected or production should cancel

        reconciliation_state = "existing_refunded" if already_refunded else "refunded"

        update_entity_index(
            orders_index_file,
            "orders",
            "order_id",
            {
                "order_id": order_id,
                "current_revision_id": order.get("current_revision_id"),
                "active_quote_id": order.get("active_quote_id"),
                "customer_id": order.get("customer_id"),
                "lifecycle_state": order.get("lifecycle_state"),
                "payment_state": order.get("payment_state"),
                "source_quote_packet_id": order.get("source_quote_packet_id"),
                "created_at": order.get("created_at"),
                "updated_at": timestamp,
            },
        )
    elif payment_record_status in PAID_RECORD_STATES:
        if provider_payment_status != "paid":
            reconciliation_state = "pending_reconciliation"
        else:
            derived_order_payment_state = derive_order_payment_state(synced_ref, quote, order)
            paid_at = str(payment_record.get("updated_at") or "").strip() or timestamp
            already_projected = (
                str(order.get("payment_state") or "") == derived_order_payment_state
                and str(quote.get("quote_state") or "") == "accepted"
                and (
                    (derived_order_payment_state == "paid" and str(packet.get("state") or "") == "paid")
                    or (derived_order_payment_state == "partially_paid" and str(packet.get("state") or "") == "sent")
                )
            )

            order["payment_state"] = derived_order_payment_state
            if str(order.get("lifecycle_state") or "") == "quoted":
                order["lifecycle_state"] = "approved"
            order["updated_at"] = timestamp

            quote["quote_state"] = "accepted"
            quote["updated_at"] = timestamp

            if derived_order_payment_state == "paid":
                packet["state"] = "paid"
                packet["paid_at"] = paid_at
                reconciliation_state = "existing_paid" if already_projected else "paid"
            else:
                packet["state"] = "sent"
                reconciliation_state = "existing_partially_paid" if already_projected else "partially_paid"

            update_entity_index(
                orders_index_file,
                "orders",
                "order_id",
                {
                    "order_id": order_id,
                    "current_revision_id": order.get("current_revision_id"),
                    "active_quote_id": order.get("active_quote_id"),
                    "customer_id": order.get("customer_id"),
                    "lifecycle_state": order.get("lifecycle_state"),
                    "payment_state": order.get("payment_state"),
                    "source_quote_packet_id": order.get("source_quote_packet_id"),
                    "created_at": order.get("created_at"),
                    "updated_at": timestamp,
                },
            )
            update_entity_index(
                quotes_index_file,
                "quotes",
                "quote_id",
                {
                    "quote_id": quote["quote_id"],
                    "order_id": order_id,
                    "order_revision_id": quote.get("order_revision_id"),
                    "quote_state": quote["quote_state"],
                    "source_quote_packet_id": quote.get("source_quote_packet_id"),
                    "created_at": quote.get("created_at"),
                    "updated_at": timestamp,
                },
            )

    dump_yaml(packet_file, packet)
    dump_yaml(quote_file, quote)
    dump_yaml(order_file, order)
    update_index(packet_index_file, packet, timestamp)

    return print_summary(reconciliation_state, packet, quote, order, synced_ref, packet_file, quote_file, order_file)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
