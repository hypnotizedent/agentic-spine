#!/usr/bin/env python3
"""Send promoted Mint quotes through the governed communications pipeline."""

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

from quote_packet_normalize import append_receipt, dump_yaml, fail, load_structured_file, now_utc, update_index


TERMINAL_PACKET_STATES = {"paid", "closed"}
VALID_SEND_PACKET_STATES = {"approved_to_send", "sent"}
VALID_CONSENT_STATES = {"opted-in", "opted-out", "unknown"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-send",
        description="Send a promoted Mint quote through communications.send.preview -> communications.send.execute.",
    )
    parser.add_argument("packet_id", help="quote_packet_id to send")
    parser.add_argument(
        "--consent-state",
        choices=sorted(VALID_CONSENT_STATES),
        help="Explicit email consent override when the packet does not already carry consent projection",
    )
    parser.add_argument(
        "--preview-only",
        action="store_true",
        help="Run governed communications preview only and do not execute the send or mutate quote state",
    )
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.send"


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


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


def append_path_receipt(
    existing_receipts: list[dict[str, Any]], receipt_path: str, capability_name: str, timestamp: str
) -> list[dict[str, Any]]:
    if not receipt_path:
        return copy.deepcopy(existing_receipts)

    receipts = copy.deepcopy(existing_receipts)
    normalized = str(receipt_path).strip()
    if any(
        isinstance(entry, dict)
        and str(entry.get("receipt_path") or "").strip() == normalized
        and str(entry.get("capability_name") or "").strip() == capability_name
        for entry in receipts
    ):
        return receipts

    receipts.append(
        {
            "receipt_path": normalized,
            "capability_name": capability_name,
            "run_key": os.environ.get("SPINE_CAP_RUN_KEY", ""),
            "executed_at": timestamp,
        }
    )
    return receipts


def as_decimal(value: Any) -> Decimal:
    if value in (None, ""):
        return Decimal("0.00")
    try:
        return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except Exception:  # pragma: no cover - defensive
        return Decimal("0.00")


def format_money(value: Any) -> str:
    return f"${as_decimal(value):,.2f}"


def normalize_consent_value(value: Any) -> str:
    if isinstance(value, bool):
        return "opted-in" if value else "opted-out"
    token = str(value or "").strip().lower()
    if token in {"opted-in", "opted_in", "optin", "opt_in", "yes", "true", "1"}:
        return "opted-in"
    if token in {"opted-out", "opted_out", "optout", "opt_out", "no", "false", "0"}:
        return "opted-out"
    return "unknown"


def derived_email_consent(packet: dict[str, Any], explicit: str | None) -> str:
    if explicit:
        return explicit

    customer_ref = packet.get("customer_ref") or {}
    for field in ("email_consent_state", "email_opt_in", "email_consent", "consent_state_email"):
        if field in customer_ref:
            return normalize_consent_value(customer_ref.get(field))
    return "unknown"


def customer_display_name(packet: dict[str, Any], quote: dict[str, Any]) -> str:
    customer_ref = packet.get("customer_ref") or {}
    return str(
        customer_ref.get("resolved_name")
        or quote.get("customer_name")
        or customer_ref.get("customer_query")
        or customer_ref.get("customer_id")
        or "Customer"
    )


def payment_ref(packet: dict[str, Any]) -> dict[str, Any]:
    value = packet.get("payment_ref")
    return value if isinstance(value, dict) else {}


def quote_send_blocking_reasons(packet: dict[str, Any], quote: dict[str, Any]) -> list[str]:
    reasons: list[str] = []
    state = str(packet.get("state") or "")
    if state in TERMINAL_PACKET_STATES:
        reasons.append(f"packet is already in terminal state {state}")
    elif state not in VALID_SEND_PACKET_STATES:
        reasons.append(f"packet state is {state} (must be approved_to_send or sent)")

    blocking_gaps = [gap for gap in packet.get("open_gaps") or [] if isinstance(gap, dict) and gap.get("severity") == "blocking"]
    if blocking_gaps:
        reasons.append(f"packet has {len(blocking_gaps)} blocking gaps")

    customer_ref = packet.get("customer_ref") or {}
    if customer_ref.get("identity_state") != "resolved":
        reasons.append("customer identity is not resolved")
    if not str(customer_ref.get("resolved_email") or "").strip():
        reasons.append("resolved customer email is required before quote send")

    if not isinstance(packet.get("quote_draft_ref"), dict):
        reasons.append("quote_draft_ref is missing")
    if not str(packet.get("customer_message_draft") or "").strip():
        reasons.append("customer_message_draft is missing")

    packet_quote_id = str(packet.get("quote_id") or "").strip()
    quote_id = str(quote.get("quote_id") or "").strip()
    if not packet_quote_id:
        reasons.append("canonical quote_id missing from quote_packet")
    elif packet_quote_id != quote_id:
        reasons.append("quote_packet quote_id does not match canonical quote")

    packet_order_id = str(packet.get("order_id") or "").strip()
    quote_order_id = str(quote.get("order_id") or "").strip()
    if not packet_order_id:
        reasons.append("canonical order_id missing from quote_packet")
    elif packet_order_id != quote_order_id:
        reasons.append("quote_packet order_id does not match canonical quote")

    payment = payment_ref(packet)
    if not payment:
        reasons.append("payment_ref missing (run mint.quote.generate_payment_link first)")
    else:
        if str(payment.get("payment_link_state") or "") != "generated":
            reasons.append("payment_ref must be generated before send")
        if not str(payment.get("payment_link_url") or "").strip():
            reasons.append("payment_link_url missing from payment_ref")
        quote_payment = quote.get("payment_ref") if isinstance(quote.get("payment_ref"), dict) else {}
        if not quote_payment:
            reasons.append("canonical quote payment_ref missing")
        else:
            if str(quote_payment.get("payment_link_state") or "") != "generated":
                reasons.append("canonical quote payment_ref must be generated before send")
            if str(quote_payment.get("checkout_session_id") or quote_payment.get("payment_link_id") or "") != str(
                payment.get("checkout_session_id") or payment.get("payment_link_id") or ""
            ):
                reasons.append("quote payment_ref checkout_session_id does not match quote_packet payment_ref")
            if str(quote_payment.get("payment_link_url") or "").strip() != str(payment.get("payment_link_url") or "").strip():
                reasons.append("quote payment_ref payment_link_url does not match quote_packet payment_ref")

    quote_state = str(quote.get("quote_state") or "")
    if quote_state not in {"draft", "sent"}:
        reasons.append(f"quote_state is {quote_state} (must be draft before first send)")

    if state == "sent" and quote_state != "sent":
        reasons.append("packet is already sent but canonical quote_state is not sent")
    if quote_state == "sent" and state != "sent":
        reasons.append("canonical quote_state is sent but quote_packet state is not sent")

    return reasons


def default_preview_bin(spine_root: Path) -> str:
    return str(spine_root / "ops/plugins/domains/communications/bin/communications-send-preview")


def default_execute_bin(spine_root: Path) -> str:
    return str(spine_root / "ops/plugins/domains/communications/bin/communications-send-execute")


def communication_bins(spine_root: Path) -> tuple[str, str]:
    preview_bin = os.environ.get("MINT_QUOTE_SEND_PREVIEW_BIN") or default_preview_bin(spine_root)
    execute_bin = os.environ.get("MINT_QUOTE_SEND_EXECUTE_BIN") or default_execute_bin(spine_root)
    if not Path(preview_bin).exists():
        fail(f"communications preview surface not found: {preview_bin}")
    if not Path(execute_bin).exists():
        fail(f"communications execute surface not found: {execute_bin}")
    return preview_bin, execute_bin


def run_json_command(command: list[str], label: str) -> dict[str, Any]:
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        details = (result.stderr or result.stdout or "").strip()
        fail(f"{label} failed: {details or f'exit {result.returncode}'}")
    try:
        payload = json.loads(result.stdout or "{}")
    except json.JSONDecodeError as exc:
        fail(f"{label} returned invalid JSON: {exc}")
    if not isinstance(payload, dict):
        fail(f"{label} returned a non-object payload")
    return payload


def send_template_vars(packet: dict[str, Any], quote: dict[str, Any]) -> dict[str, Any]:
    payment = payment_ref(packet)
    return {
        "customer_name": customer_display_name(packet, quote),
        "order_number": str(packet.get("order_id") or quote.get("order_id") or ""),
        "balance_amount": format_money(payment.get("payment_amount") or ((packet.get("pricing_snapshot") or {}).get("calculated_totals") or {}).get("total")),
        "payment_link": str(payment.get("payment_link_url") or ""),
    }


def receipt_hint(packet: dict[str, Any], capability_name: str) -> str:
    for entry in packet.get("receipts") or []:
        if not isinstance(entry, dict):
            continue
        if str(entry.get("capability_name") or "") == capability_name:
            return str(entry.get("receipt_path") or "")
    return ""


def print_existing_summary(packet: dict[str, Any], quote: dict[str, Any], quote_file: Path, packet_file: Path) -> int:
    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"quote_id: {quote['quote_id']}")
    print("send_status: existing")
    print(f"state: {packet['state']}")
    print(f"sent_at: {packet.get('sent_at') or ''}")
    preview_receipt = receipt_hint(packet, "communications.send.preview")
    execute_receipt = receipt_hint(packet, "communications.send.execute")
    if preview_receipt:
        print(f"preview_receipt: {preview_receipt}")
    if execute_receipt:
        print(f"delivery_record: {execute_receipt}")
    print(f"packet_file: {packet_file}")
    print(f"quote_file: {quote_file}")
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

    packet_file = packet_file_for_id(packets_dir, args.packet_id)
    if not packet_file.exists():
        fail(f"packet not found: {args.packet_id}")

    packet = load_structured_file(packet_file) or {}
    if not isinstance(packet, dict):
        fail(f"quote_packet is not a valid object: {args.packet_id}")

    quote_id = str(packet.get("quote_id") or "").strip()
    if not quote_id:
        fail("canonical quote_id missing (run quote-promote first)")
    quote_file = entity_file(quotes_dir, "quote", quote_id)
    if not quote_file.exists():
        fail(f"canonical quote not found: {quote_id}")

    quote = load_structured_file(quote_file) or {}
    if not isinstance(quote, dict):
        fail(f"quote is not a valid object: {quote_id}")

    blocking_reasons = quote_send_blocking_reasons(packet, quote)
    if blocking_reasons:
        fail("cannot send: " + "; ".join(blocking_reasons))

    if packet.get("state") == "sent" and quote.get("quote_state") == "sent" and packet.get("sent_at"):
        return print_existing_summary(packet, quote, quote_file, packet_file)

    preview_bin, execute_bin = communication_bins(spine_root)
    consent_state = derived_email_consent(packet, args.consent_state)
    template_vars = send_template_vars(packet, quote)
    preview_payload = run_json_command(
        [
            preview_bin,
            "--channel",
            "email",
            "--message-type",
            "payment_needed",
            "--to",
            str((packet.get("customer_ref") or {}).get("resolved_email") or ""),
            "--vars-json",
            json.dumps(template_vars),
            "--consent-state",
            consent_state,
            "--json",
        ],
        "communications.send.preview",
    )
    preview_data = preview_payload.get("data") or {}
    if not isinstance(preview_data, dict):
        fail("communications.send.preview did not return a valid data object")

    if str(preview_data.get("provider") or "") != "resend":
        fail(f"canonical Mint customer send must route through resend, found provider={preview_data.get('provider') or 'unknown'}")
    if str(preview_data.get("channel") or "") != "email":
        fail("communications preview returned a non-email route for Mint quote send")
    if str(preview_data.get("message_type") or "") != "payment_needed":
        fail("communications preview returned an unexpected message_type for Mint quote send")
    if preview_data.get("send_allowed") is not True:
        reasons = preview_data.get("policy_block_reasons") or []
        if isinstance(reasons, list):
            fail("cannot send: communications preview blocked send (" + ", ".join(str(reason) for reason in reasons) + ")")
        fail("cannot send: communications preview blocked send")

    preview_id = str(preview_data.get("preview_id") or "").strip()
    preview_receipt = str(preview_data.get("preview_receipt") or "").strip()
    if not preview_id or not preview_receipt:
        fail("communications.send.preview did not return preview linkage")

    preview_subject = str(preview_data.get("subject") or "").strip()
    preview_body = str(preview_data.get("body") or "").strip()

    if args.preview_only:
        print(f"quote_packet_id: {packet['quote_packet_id']}")
        print(f"quote_id: {quote['quote_id']}")
        print("send_status: preview_ready")
        print("message_type: payment_needed")
        print("provider: resend")
        print(f"consent_state: {consent_state}")
        print(f"preview_id: {preview_id}")
        print(f"preview_receipt: {preview_receipt}")
        if preview_subject:
            print(f"subject: {preview_subject}")
        print(f"packet_file: {packet_file}")
        print(f"quote_file: {quote_file}")
        return 0

    execute_payload = run_json_command(
        [
            execute_bin,
            "--preview-id",
            preview_id,
            "--preview-receipt",
            preview_receipt,
            "--execute",
            "--json",
        ],
        "communications.send.execute",
    )
    execute_data = execute_payload.get("data") or {}
    if not isinstance(execute_data, dict):
        fail("communications.send.execute did not return a valid data object")

    execute_status = str(execute_payload.get("status") or "").strip()
    if execute_status == "simulated":
        stop("communications send remained simulated; packet not marked sent")
    if execute_status != "sent":
        error_message = (execute_payload.get("error") or {}).get("message") if isinstance(execute_payload.get("error"), dict) else ""
        fail(f"communications send failed: {error_message or execute_status or 'unknown error'}")

    if str(execute_data.get("provider") or "resend") != "resend":
        fail("communications execute drifted away from the canonical resend route")

    timestamp = now_utc()
    packet["state"] = "sent"
    packet["sent_at"] = timestamp
    packet["updated_at"] = timestamp
    packet["customer_message_draft"] = preview_body
    receipts = packet.get("receipts") or []
    receipts = append_path_receipt(receipts, preview_receipt, "communications.send.preview", timestamp)
    receipts = append_path_receipt(receipts, str(execute_data.get("record") or ""), "communications.send.execute", timestamp)
    receipts = append_receipt(receipts, current_capability_name(), timestamp)
    packet["receipts"] = receipts

    quote["quote_state"] = "sent"
    quote["sent_at"] = timestamp
    quote["updated_at"] = timestamp

    dump_yaml(packet_file, packet)
    dump_yaml(quote_file, quote)
    update_index(packet_index_file, packet, timestamp)
    update_entity_index(
        quotes_index_file,
        "quotes",
        "quote_id",
        {
            "quote_id": quote_id,
            "order_id": quote.get("order_id"),
            "order_revision_id": quote.get("order_revision_id"),
            "quote_state": "sent",
            "source_quote_packet_id": quote.get("source_quote_packet_id"),
            "sent_at": timestamp,
            "updated_at": timestamp,
        },
    )

    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"quote_id: {quote_id}")
    print(f"state: sent")
    print("send_status: success")
    print("message_type: payment_needed")
    print("provider: resend")
    print(f"consent_state: {consent_state}")
    print(f"preview_id: {preview_id}")
    print(f"preview_receipt: {preview_receipt}")
    print(f"delivery_event_id: {execute_data.get('event_id') or ''}")
    print(f"delivery_record: {execute_data.get('record') or ''}")
    if execute_data.get("provider_message_id"):
        print(f"provider_message_id: {execute_data['provider_message_id']}")
    print(f"packet_file: {packet_file}")
    print(f"quote_file: {quote_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
