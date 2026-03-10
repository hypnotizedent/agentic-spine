#!/usr/bin/env python3
"""Generate Stripe checkout links from promoted Mint quote truth."""

from __future__ import annotations

import argparse
import copy
import json
import os
import subprocess
import sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

from quote_packet_normalize import append_receipt, dump_yaml, fail, load_structured_file, now_utc, update_index


TERMINAL_PACKET_STATES = {"paid", "closed"}
ACTIVE_PAYMENT_LINK_STATES = {"generated"}
VALID_PAYMENT_TYPES = {"deposit", "balance", "full", "partial"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-generate-payment-link",
        description="Generate a Stripe checkout session for a promoted Mint quote.",
    )
    parser.add_argument("quote_id", help="Canonical quote_id to bridge into payment")
    parser.add_argument(
        "--payment-type",
        choices=sorted(VALID_PAYMENT_TYPES),
        default="full",
        help="Payment type to request from the payment module (default: full)",
    )
    parser.add_argument("--timeout-seconds", type=int, default=45, help="HTTP timeout for payment requests")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.generate_payment_link"


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


def as_decimal(value: Any) -> Decimal:
    if value in (None, ""):
        return Decimal("0.00")
    try:
        return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except Exception:  # pragma: no cover - defensive
        return Decimal("0.00")


def money_to_cents(value: Any) -> int:
    return int((as_decimal(value) * 100).to_integral_value(rounding=ROUND_HALF_UP))


def cents_to_amount(value: Any) -> float:
    try:
        cents = int(value)
    except Exception:  # pragma: no cover - defensive
        cents = 0
    return float((Decimal(cents) / Decimal("100")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def packet_file_for_id(packets_dir: Path, packet_id: str) -> Path:
    return packets_dir / f"quote_packet_{packet_id}.yaml"


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


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


def canonical_payment_base_url(spine_root: Path) -> str:
    override = os.environ.get("PAYMENT_BASE_URL")
    if override:
        return override.rstrip("/")

    services_file = spine_root / "ops/bindings/services.health.yaml"
    if services_file.exists():
        services = load_structured_file(services_file) or {}
        for endpoint in services.get("endpoints") or []:
            if not isinstance(endpoint, dict) or endpoint.get("id") != "payment-v2":
                continue
            raw_url = str(endpoint.get("url") or "").strip()
            if not raw_url:
                continue
            parsed = urlparse.urlparse(raw_url)
            if parsed.scheme and parsed.netloc:
                return f"{parsed.scheme}://{parsed.netloc}"

    return "http://192.168.1.213:4000"


def resolve_payment_api_key(spine_root: Path) -> str:
    env_value = os.environ.get("PAYMENT_API_KEY", "").strip()
    if env_value:
        return env_value

    infisical_agent = spine_root / "ops/plugins/providers/bin/infisical-agent.sh"
    if not infisical_agent.exists():
        return ""

    result = subprocess.run(
        [str(infisical_agent), "get-cached", "infrastructure", "prod", "PAYMENT_API_KEY"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def active_payment_ref(payment_ref: Any) -> dict[str, Any] | None:
    if not isinstance(payment_ref, dict):
        return None
    state = str(payment_ref.get("payment_link_state") or "")
    url = str(payment_ref.get("payment_link_url") or "")
    session_id = str(payment_ref.get("checkout_session_id") or payment_ref.get("payment_link_id") or "")
    if state not in ACTIVE_PAYMENT_LINK_STATES:
        return None
    if not url or "PLACEHOLDER" in url or not session_id:
        return None

    normalized = copy.deepcopy(payment_ref)
    normalized["payment_link_state"] = "generated"
    normalized["payment_link_id"] = str(normalized.get("payment_link_id") or session_id)
    normalized["checkout_session_id"] = session_id
    currency = str(normalized.get("payment_currency") or "").strip()
    if currency:
        normalized["payment_currency"] = currency.upper()
    if normalized.get("payment_amount_cents") in (None, "") and normalized.get("payment_amount") not in (None, ""):
        normalized["payment_amount_cents"] = money_to_cents(normalized.get("payment_amount"))
    if normalized.get("payment_amount") in (None, "") and normalized.get("payment_amount_cents") not in (None, ""):
        normalized["payment_amount"] = cents_to_amount(normalized.get("payment_amount_cents"))
    return normalized


def select_existing_payment_ref(packet: dict[str, Any], quote: dict[str, Any], quote_id: str, order_id: str) -> tuple[dict[str, Any] | None, bool]:
    packet_ref = active_payment_ref(packet.get("payment_ref"))
    quote_ref = active_payment_ref(quote.get("payment_ref"))

    if packet_ref and quote_ref:
        if packet_ref.get("checkout_session_id") != quote_ref.get("checkout_session_id"):
            fail("packet and quote carry conflicting checkout_session_id values")
        if packet_ref.get("payment_link_url") != quote_ref.get("payment_link_url"):
            fail("packet and quote carry conflicting payment_link_url values")

    chosen = packet_ref or quote_ref
    if not chosen:
        return None, False

    if chosen.get("quote_id") not in (None, "", quote_id):
        fail("existing payment_ref is bound to a different quote_id")
    if chosen.get("order_id") not in (None, "", order_id):
        fail("existing payment_ref is bound to a different order_id")

    chosen = copy.deepcopy(chosen)
    chosen["quote_id"] = quote_id
    chosen["order_id"] = order_id
    chosen["payment_type"] = str(chosen.get("payment_type") or "full")
    needs_sync = packet_ref != chosen or quote_ref != chosen
    return chosen, needs_sync


def line_price_map(packet: dict[str, Any]) -> dict[str, dict[str, Any]]:
    pricing_snapshot = packet.get("pricing_snapshot") or {}
    mapped: dict[str, dict[str, Any]] = {}
    for idx, entry in enumerate(pricing_snapshot.get("line_item_prices") or []):
        if not isinstance(entry, dict):
            continue
        line_item_id = entry.get("line_item_id")
        if not line_item_id:
            line_items = packet.get("line_items") or []
            if idx < len(line_items) and isinstance(line_items[idx], dict):
                line_item_id = line_items[idx].get("line_item_id")
        if line_item_id:
            mapped[str(line_item_id)] = entry
    return mapped


def describe_line_item(item: dict[str, Any]) -> str:
    return str(item.get("description") or item.get("product_type") or item.get("line_item_id") or "Line item")


def checkout_line_items(packet: dict[str, Any], quote_amount_cents: int) -> list[dict[str, Any]]:
    mapped_prices = line_price_map(packet)
    checkout_items: list[dict[str, Any]] = []
    running_total = 0

    for item in packet.get("line_items") or []:
        if not isinstance(item, dict):
            continue
        line_item_id = str(item.get("line_item_id") or "")
        quantity = item.get("quantity")
        try:
            quantity_int = int(quantity)
        except Exception:
            return []
        if quantity_int <= 0:
            return []

        price_entry = mapped_prices.get(line_item_id) or {}
        unit_cents = 0
        if price_entry.get("unit_price_cents") not in (None, ""):
            unit_cents = int(price_entry["unit_price_cents"])
        elif price_entry.get("unit_price") not in (None, ""):
            unit_cents = money_to_cents(price_entry["unit_price"])
        elif price_entry.get("line_total_cents") not in (None, ""):
            unit_cents = int(Decimal(int(price_entry["line_total_cents"])) / Decimal(quantity_int))
        elif price_entry.get("line_total") not in (None, ""):
            line_total_cents = money_to_cents(price_entry["line_total"])
            unit_cents = int(Decimal(line_total_cents) / Decimal(quantity_int))
        if unit_cents <= 0:
            return []

        checkout_items.append(
            {
                "name": describe_line_item(item),
                "quantity": quantity_int,
                "amount_cents": unit_cents,
            }
        )
        running_total += unit_cents * quantity_int

    totals = (packet.get("pricing_snapshot") or {}).get("calculated_totals") or {}
    shipping_cents = money_to_cents(totals.get("shipping"))
    tax_cents = money_to_cents(totals.get("tax"))
    if shipping_cents > 0:
        checkout_items.append({"name": "Shipping", "quantity": 1, "amount_cents": shipping_cents})
        running_total += shipping_cents
    if tax_cents > 0:
        checkout_items.append({"name": "Tax", "quantity": 1, "amount_cents": tax_cents})
        running_total += tax_cents

    return checkout_items if running_total == quote_amount_cents and checkout_items else []


def quote_description(packet: dict[str, Any], quote: dict[str, Any]) -> str:
    draft_payload = ((packet.get("quote_draft_ref") or {}).get("draft_payload") or {})
    title = str(draft_payload.get("title") or quote.get("quote_label") or "").strip()
    if title:
        return title
    customer_name = str(quote.get("customer_name") or packet.get("customer_ref", {}).get("resolved_name") or "").strip()
    if customer_name:
        return f"Quote for {customer_name}"
    return f"Quote {quote.get('quote_id')}"


def build_payment_request(packet: dict[str, Any], quote: dict[str, Any], payment_type: str) -> dict[str, Any]:
    quote_amount_cents = int(quote.get("amount_cents") or 0)
    currency = str(quote.get("currency") or "usd").strip().lower() or "usd"
    customer_email = str(
        quote.get("customer_email")
        or (packet.get("customer_ref") or {}).get("resolved_email")
        or ""
    ).strip()
    payload: dict[str, Any] = {
        "order_id": str(quote["order_id"]),
        "amount_cents": quote_amount_cents,
        "currency": currency,
        "customer_email": customer_email,
        "payment_type": payment_type,
        "description": quote_description(packet, quote),
    }
    checkout_items = checkout_line_items(packet, quote_amount_cents)
    if checkout_items:
        payload["line_items"] = checkout_items
    return payload


def post_checkout_session(base_url: str, api_key: str, payload: dict[str, Any], timeout_seconds: int) -> dict[str, Any]:
    encoded = json.dumps(payload).encode("utf-8")
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/v1/payments/checkout-session",
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-API-Key": api_key,
        },
        data=encoded,
        method="POST",
    )
    with urlrequest.urlopen(request, timeout=timeout_seconds) as response:
        body = response.read().decode("utf-8")
    return json.loads(body or "{}")


def payment_blocking_reasons(packet: dict[str, Any], quote: dict[str, Any], order: dict[str, Any], payment_type: str) -> list[str]:
    reasons: list[str] = []
    packet_state = str(packet.get("state") or "")
    if packet_state in TERMINAL_PACKET_STATES:
        reasons.append(f"packet is already in terminal state {packet_state}")
    elif packet_state not in {"approved_to_send", "sent"}:
        reasons.append(f"packet state is {packet_state} (must be approved_to_send before payment link generation)")

    if not str(packet.get("quote_id") or "").strip():
        reasons.append("quote_packet is missing quote_id")
    elif str(packet.get("quote_id") or "").strip() != str(quote.get("quote_id") or "").strip():
        reasons.append("quote_packet quote_id does not match the canonical quote")

    if not str(packet.get("order_id") or "").strip():
        reasons.append("quote_packet is missing order_id")
    elif str(packet.get("order_id") or "").strip() != str(quote.get("order_id") or "").strip():
        reasons.append("quote_packet order_id does not match the canonical quote")

    if str(quote.get("quote_state") or "") != "draft":
        reasons.append(f"quote_state is {quote.get('quote_state') or 'unknown'} (must be draft for first payment link generation)")

    if not str(quote.get("order_id") or "").strip():
        reasons.append("quote is missing order_id")
    if int(quote.get("amount_cents") or 0) <= 0:
        reasons.append("quote amount_cents must be positive")

    customer_email = str(
        quote.get("customer_email")
        or (packet.get("customer_ref") or {}).get("resolved_email")
        or ""
    ).strip()
    if not customer_email:
        reasons.append("resolved customer email is required before payment link generation")

    if not isinstance(order, dict) or not order:
        reasons.append("canonical order record is missing")
    else:
        payment_state = str(order.get("payment_state") or "")
        if payment_state in {"paid", "refunded"}:
            reasons.append(f"order payment_state is {payment_state}")
        elif payment_state == "partially_paid" and payment_type == "full":
            reasons.append("order is already partially_paid; generate a balance or partial payment link instead of full")

    pricing_snapshot = packet.get("pricing_snapshot") or {}
    if str(pricing_snapshot.get("pricing_state") or "") != "completed":
        reasons.append("quote_packet pricing_snapshot must be completed")
    packet_total_cents = money_to_cents((pricing_snapshot.get("calculated_totals") or {}).get("total"))
    if packet_total_cents and int(quote.get("amount_cents") or 0) != packet_total_cents:
        reasons.append("quote amount_cents does not match the promoted pricing_snapshot total")

    return reasons


def build_payment_ref(response: dict[str, Any], quote_id: str, order_id: str, payment_type: str, timestamp: str) -> dict[str, Any]:
    checkout_session_id = str(response.get("checkout_session_id") or "").strip()
    checkout_url = str(response.get("checkout_url") or "").strip()
    amount_cents = int(response.get("amount_cents") or 0)
    currency = str(response.get("currency") or "usd").strip().upper() or "USD"
    if not checkout_session_id or not checkout_url:
        fail("payment module response is missing checkout session details")

    return {
        "payment_provider": "stripe",
        "payment_link_id": checkout_session_id,
        "checkout_session_id": checkout_session_id,
        "payment_link_url": checkout_url,
        "payment_link_state": "generated",
        "payment_amount": cents_to_amount(amount_cents),
        "payment_amount_cents": amount_cents,
        "payment_currency": currency,
        "payment_type": payment_type,
        "quote_id": quote_id,
        "order_id": order_id,
        "generated_at": timestamp,
    }


def print_summary(
    status: str,
    quote: dict[str, Any],
    packet: dict[str, Any],
    payment_ref: dict[str, Any],
    quote_file: Path,
    packet_file: Path,
) -> int:
    print(f"quote_id: {quote['quote_id']}")
    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"payment_link_state: {status}")
    print(f"checkout_session_id: {payment_ref['checkout_session_id']}")
    print(f"payment_link_url: {payment_ref['payment_link_url']}")
    print(f"payment_amount_cents: {payment_ref['payment_amount_cents']}")
    print(f"payment_type: {payment_ref['payment_type']}")
    print(f"quote_file: {quote_file}")
    print(f"packet_file: {packet_file}")
    return 0


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    spine_root = Path(os.environ.get("SPINE_ROOT") or script_dir.parent.parent.parent.parent)
    mint_root = spine_root / "runtime/domain-state/mint"

    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (mint_root / "quote-packets"))
    packet_index_file = Path(os.environ.get("MINT_QUOTE_PACKET_INDEX_FILE") or (mint_root / "quote-packets-index.yaml"))
    quotes_dir = Path(os.environ.get("MINT_QUOTES_DIR") or (mint_root / "quotes"))
    quotes_index_file = Path(os.environ.get("MINT_QUOTES_INDEX_FILE") or (mint_root / "quotes-index.yaml"))
    orders_dir = Path(os.environ.get("MINT_ORDER_RUNTIME_DIR") or (mint_root / "orders"))

    quote_file = entity_file(quotes_dir, "quote", args.quote_id)
    if not quote_file.exists():
        fail(f"quote not found: {args.quote_id}")

    quote = load_structured_file(quote_file) or {}
    if not isinstance(quote, dict):
        fail(f"quote is not a valid object: {args.quote_id}")

    source_quote_packet_id = str(quote.get("source_quote_packet_id") or "").strip()
    if not source_quote_packet_id:
        fail("quote is missing source_quote_packet_id linkage back to quote_packet")

    packet_file = packet_file_for_id(packets_dir, source_quote_packet_id)
    if not packet_file.exists():
        fail(f"source quote_packet not found for quote {args.quote_id}: {source_quote_packet_id}")

    packet = load_structured_file(packet_file) or {}
    if not isinstance(packet, dict):
        fail(f"quote_packet is not a valid object: {source_quote_packet_id}")

    order_id = str(quote.get("order_id") or packet.get("order_id") or "").strip()
    if not order_id:
        fail("promoted quote is missing canonical order_id")
    order_file = entity_file(orders_dir, "order", order_id)
    order = load_existing_or_none(order_file) or {}

    existing_payment_ref, needs_sync = select_existing_payment_ref(packet, quote, args.quote_id, order_id)
    if existing_payment_ref is not None:
        if needs_sync:
            timestamp = now_utc()
            packet["payment_ref"] = copy.deepcopy(existing_payment_ref)
            packet["updated_at"] = timestamp
            packet["receipts"] = append_receipt(packet.get("receipts") or [], current_capability_name(), timestamp)
            quote["payment_ref"] = copy.deepcopy(existing_payment_ref)
            quote["updated_at"] = timestamp
            dump_yaml(packet_file, packet)
            dump_yaml(quote_file, quote)
            update_index(packet_index_file, packet, timestamp)
            update_entity_index(
                quotes_index_file,
                "quotes",
                "quote_id",
                {
                    "quote_id": args.quote_id,
                    "order_id": order_id,
                    "quote_state": quote.get("quote_state"),
                    "payment_link_state": existing_payment_ref["payment_link_state"],
                    "payment_generated_at": existing_payment_ref.get("generated_at"),
                    "source_quote_packet_id": source_quote_packet_id,
                    "updated_at": timestamp,
                },
            )
            return print_summary("synced_existing", quote, packet, existing_payment_ref, quote_file, packet_file)
        return print_summary("existing", quote, packet, existing_payment_ref, quote_file, packet_file)

    blocking_reasons = payment_blocking_reasons(packet, quote, order, args.payment_type)
    if blocking_reasons:
        fail("cannot generate payment link: " + "; ".join(blocking_reasons))

    api_key = resolve_payment_api_key(spine_root)
    if not api_key:
        fail("PAYMENT_API_KEY is unavailable for the governed quote payment bridge")

    request_payload = build_payment_request(packet, quote, args.payment_type)
    base_url = canonical_payment_base_url(spine_root)
    try:
        response = post_checkout_session(base_url, api_key, request_payload, args.timeout_seconds)
    except urlerror.HTTPError as exc:
        payload = exc.read().decode("utf-8") if exc.fp else ""
        try:
            details = json.loads(payload or "{}")
        except json.JSONDecodeError:
            details = {}
        message = details.get("error") if isinstance(details, dict) else ""
        if exc.code in {401, 403}:
            fail(f"payment service rejected the configured API key (HTTP {exc.code})")
        fail(f"payment service returned HTTP {exc.code}: {message or 'checkout session creation failed'}")
    except urlerror.URLError as exc:
        fail(f"payment service unavailable: {exc.reason}")

    timestamp = now_utc()
    payment_ref = build_payment_ref(response, args.quote_id, order_id, args.payment_type, timestamp)

    packet["payment_ref"] = copy.deepcopy(payment_ref)
    packet["updated_at"] = timestamp
    packet["receipts"] = append_receipt(packet.get("receipts") or [], current_capability_name(), timestamp)

    quote["payment_ref"] = copy.deepcopy(payment_ref)
    quote["updated_at"] = timestamp

    dump_yaml(packet_file, packet)
    dump_yaml(quote_file, quote)
    update_index(packet_index_file, packet, timestamp)
    update_entity_index(
        quotes_index_file,
        "quotes",
        "quote_id",
        {
            "quote_id": args.quote_id,
            "order_id": order_id,
            "order_revision_id": quote.get("order_revision_id"),
            "quote_state": quote.get("quote_state"),
            "payment_link_state": payment_ref["payment_link_state"],
            "payment_generated_at": timestamp,
            "source_quote_packet_id": source_quote_packet_id,
            "updated_at": timestamp,
        },
    )

    return print_summary("generated", quote, packet, payment_ref, quote_file, packet_file)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
