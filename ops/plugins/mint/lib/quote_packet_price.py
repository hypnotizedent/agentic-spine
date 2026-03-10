#!/usr/bin/env python3
"""Persist real pricing snapshots for governed quote_packet work objects."""

from __future__ import annotations

import argparse
import copy
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

from quote_packet_normalize import (
    METHODS_REQUIRING_GRAPHIC_SIZE,
    add_gap,
    append_receipt,
    dump_yaml,
    fail,
    has_canonical_value,
    load_structured_file,
    now_utc,
    overall_confidence,
    pricing_missing_fields,
    update_index,
)


TERMINAL_STATES = {"sent", "paid", "closed"}
TRANSIENT_PRICING_GAP_TYPES = {"quantity_unresolved", "decoration_unresolved", "supplier_unresolved"}
TRANSIENT_PRICING_GAP_PREFIXES = (
    "Pricing validation failed for ",
    "Pricing runtime currently requires ",
)
PRICE_BLOCKING_GAP_TYPES = {
    "product_unresolved",
    "quantity_unresolved",
    "decoration_unresolved",
    "supplier_unresolved",
    "shipping_ambiguity",
    "pricing_policy_review",
    "clarification_required",
    "proof_routing_blocked",
}
CONFIDENCE_ORDER = {"none": 0, "low": 1, "medium": 2, "high": 3}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-price",
        description="Price a governed quote_packet through the live Mint pricing estimator.",
    )
    parser.add_argument("packet_id", help="quote_packet_id to price")
    parser.add_argument("--timeout-seconds", type=int, default=45, help="HTTP timeout for pricing requests")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.packet.price"


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


def humanize_token(value: str) -> str:
    return value.replace("_", " ").replace("-", " ").strip()


def describe_line_item(item: dict[str, Any]) -> str:
    return str(item.get("description") or item.get("product_type") or item.get("line_item_id") or "line item")


def packet_file_for_id(packets_dir: Path, packet_id: str) -> Path:
    return packets_dir / f"quote_packet_{packet_id}.yaml"


def canonical_pricing_base_url(spine_root: Path) -> str:
    override = os.environ.get("PRICING_BASE_URL")
    if override:
        return override.rstrip("/")

    services_file = spine_root / "ops/bindings/services.health.yaml"
    if services_file.exists():
        services = load_structured_file(services_file) or {}
        for endpoint in services.get("endpoints") or []:
            if not isinstance(endpoint, dict) or endpoint.get("id") != "pricing-v2":
                continue
            raw_url = str(endpoint.get("url") or "").strip()
            if not raw_url:
                continue
            parsed = urlparse.urlparse(raw_url)
            if parsed.scheme and parsed.netloc:
                return f"{parsed.scheme}://{parsed.netloc}"

    return "http://192.168.1.213:3700"


def resolve_pricing_api_key(spine_root: Path) -> str:
    env_value = os.environ.get("PRICING_API_KEY", "").strip()
    if env_value:
        return env_value

    infisical_agent = spine_root / "ops/tools/infisical-agent.sh"
    if not infisical_agent.exists():
        return ""

    result = subprocess.run(
        [str(infisical_agent), "get-cached", "infrastructure", "prod", "PRICING_API_KEY"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def prune_transient_pricing_gaps(gaps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    retained: list[dict[str, Any]] = []
    for gap in gaps:
        if not isinstance(gap, dict):
            continue
        gap_type = str(gap.get("gap_type") or "")
        description = str(gap.get("description") or "")
        if gap_type in TRANSIENT_PRICING_GAP_TYPES:
            continue
        if any(description.startswith(prefix) for prefix in TRANSIENT_PRICING_GAP_PREFIXES):
            continue
        retained.append(copy.deepcopy(gap))
    return retained


def reset_gap_ids(gaps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    for idx, gap in enumerate(gaps, start=1):
        gap["gap_id"] = idx
    return gaps


def field_label(field: str) -> str:
    if field == "prior_job_match":
        return "matching prior job evidence for re-setup pricing"
    if field == "blanks_cost_cents":
        return "blank cost"
    if field == "supplier_source":
        return "supplier source"
    if field == "color_count":
        return "color count"
    if field == "print_locations":
        return "print locations"
    if field == "graphic_size_inches":
        return "graphic size"
    return humanize_token(field)


def sync_line_item_pricing_gaps(gaps: list[dict[str, Any]], line_items: list[dict[str, Any]], timestamp: str) -> None:
    for item in line_items:
        label = describe_line_item(item)
        if not has_canonical_value(item.get("product_type")):
            add_gap(
                gaps,
                "product_unresolved",
                f"Product type is still unresolved for {label}",
                "blocking",
                "Normalize the product family before pricing",
                timestamp,
            )

        missing = pricing_missing_fields(item)
        if "quantity" in missing:
            add_gap(
                gaps,
                "quantity_unresolved",
                f"Quantity missing for {label}",
                "blocking",
                "Provide exact quantities before packet pricing",
                timestamp,
            )

        supplier_missing = [field for field in missing if field in {"blanks_cost_cents", "supplier_source"}]
        if supplier_missing:
            add_gap(
                gaps,
                "supplier_unresolved",
                f"Pricing source is incomplete for {label}: {', '.join(field_label(field) for field in supplier_missing)}",
                "blocking",
                "Ground blank cost and supplier_source in canonical supplier truth or trustworthy historical evidence",
                timestamp,
            )

        decoration_missing = [
            field
            for field in missing
            if field not in {"product_type", "quantity", "blanks_cost_cents", "supplier_source"}
        ]
        if decoration_missing:
            add_gap(
                gaps,
                "decoration_unresolved",
                f"Pricing inputs missing for {label}: {', '.join(field_label(field) for field in decoration_missing)}",
                "blocking",
                "Resolve the decoration inputs before pricing this line item",
                timestamp,
            )


def art_gap_blocks_pricing(gaps: list[dict[str, Any]], line_items: list[dict[str, Any]]) -> bool:
    blocking_art_gap = any(
        gap.get("severity") == "blocking" and gap.get("gap_type") in {"artwork_missing", "artwork_inadequate"}
        for gap in gaps
    )
    if not blocking_art_gap:
        return False

    for item in line_items:
        method = item.get("decoration_method")
        if method in METHODS_REQUIRING_GRAPHIC_SIZE and not has_canonical_value(item.get("graphic_size_inches")):
            return True
    return False


def pricing_blocking_reasons(gaps: list[dict[str, Any]], line_items: list[dict[str, Any]]) -> list[str]:
    reasons: list[str] = []
    for gap in gaps:
        if gap.get("severity") != "blocking":
            continue
        gap_type = str(gap.get("gap_type") or "")
        if gap_type in PRICE_BLOCKING_GAP_TYPES:
            reasons.append(str(gap.get("description") or gap_type))
    if art_gap_blocks_pricing(gaps, line_items):
        reasons.append("Artwork quality still blocks pricing because required size or proof truth is unresolved")
    return reasons


def inches_to_metric(graphic_size_inches: dict[str, Any] | None) -> dict[str, float] | None:
    if not isinstance(graphic_size_inches, dict):
        return None
    width_in = graphic_size_inches.get("width_in")
    height_in = graphic_size_inches.get("height_in")
    if not isinstance(width_in, (int, float)) or not isinstance(height_in, (int, float)):
        return None
    return {
        "width_cm": round(float(width_in) * 2.54, 2),
        "height_cm": round(float(height_in) * 2.54, 2),
    }


def size_tier_to_method_tier(size_tier_label: str, method: str) -> str | None:
    mapping = {
        "small_print": "small",
        "standard_print": "standard",
        "jumbo_print": "jumbo",
    }
    if method == "engraving":
        return mapping.get(size_tier_label)
    if method == "transfers":
        return mapping.get(size_tier_label)
    return None


def customer_ref_string(packet: dict[str, Any]) -> str | None:
    customer_ref = packet.get("customer_ref") or {}
    for field in ("customer_id", "resolved_email", "customer_query"):
        value = customer_ref.get(field)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def pricing_request_payload(packet: dict[str, Any], line_item: dict[str, Any], timestamp: str) -> dict[str, Any]:
    method = str(line_item["decoration_method"])
    payload: dict[str, Any] = {
        "correlation_id": f"{packet['quote_packet_id']}:{line_item['line_item_id']}",
        "request_timestamp_utc": timestamp,
        "normalization_revision": "quote_packet_v1",
        "revision": str(packet.get("updated_at") or packet.get("created_at") or packet["quote_packet_id"]),
        "item_type": method,
        "qty": int(line_item["quantity"]),
        "colors": int(line_item["color_count"]),
        "stitch_count": int(line_item.get("stitch_count") or 0),
        "locations": copy.deepcopy(line_item["print_locations"]),
        "blanks_cost": round(float(line_item["blanks_cost_cents"]) / 100, 2),
        "supplier_source": str(line_item["supplier_source"]),
        "lead_time": int(line_item["lead_time_days"]),
    }
    customer_ref = customer_ref_string(packet)
    if customer_ref:
        payload["customer_ref"] = customer_ref
    if line_item.get("inventory_as_of_utc"):
        payload["inventory_as_of_utc"] = line_item["inventory_as_of_utc"]
    if line_item.get("artwork_fingerprint_sha256"):
        payload["artwork_fingerprint_sha256"] = line_item["artwork_fingerprint_sha256"]

    if method in METHODS_REQUIRING_GRAPHIC_SIZE:
        payload["graphic_size_inches"] = copy.deepcopy(line_item["graphic_size_inches"])
        metric = inches_to_metric(line_item.get("graphic_size_inches"))
        if metric:
            payload["graphic_size_metric"] = metric
        payload["size_tier_label"] = line_item["size_tier_label"]
        payload["setup_mode"] = line_item["setup_mode"]

    if method == "screen_print":
        payload["method_variant"] = line_item["method_variant"]
        payload["underbase_needed"] = bool(line_item["underbase_needed"])
    elif method == "embroidery":
        payload["stitch_count"] = int(line_item["stitch_count"])
        payload["puff_mode"] = line_item["puff_mode"]
        payload["thread_type"] = line_item["thread_type"]
        payload["hoop_class"] = line_item["hoop_class"]
        if line_item.get("garment_material"):
            payload["garment_material"] = line_item["garment_material"]
        if line_item.get("curved_panel_cap") is not None:
            payload["curved_panel_cap"] = bool(line_item["curved_panel_cap"])
        if line_item.get("graphic_size_inches"):
            payload["graphic_size_inches"] = copy.deepcopy(line_item["graphic_size_inches"])
    elif method == "engraving":
        payload["material_class"] = line_item["material_class"]
        engraving_size_tier = size_tier_to_method_tier(str(line_item["size_tier_label"]), method)
        if engraving_size_tier:
            payload["engraving_size_tier"] = engraving_size_tier
    elif method == "transfers":
        payload["transfer_type"] = line_item["transfer_type"]
        payload["garment_family"] = line_item["garment_family"]
        transfer_size_tier = size_tier_to_method_tier(str(line_item["size_tier_label"]), method)
        if transfer_size_tier:
            payload["transfer_size_tier"] = transfer_size_tier

    return payload


def post_pricing_request(base_url: str, api_key: str, payload: dict[str, Any], timeout_seconds: int) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8")
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/v1/pricing/estimate",
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-API-Key": api_key,
        },
    )
    with urlrequest.urlopen(request, timeout=timeout_seconds) as response:
        raw = response.read().decode("utf-8")
    return json.loads(raw or "{}")


def money_from_cents(total_cents: int) -> float:
    return round(total_cents / 100, 2)


def snapshot_from_successes(
    packet: dict[str, Any],
    line_items: list[dict[str, Any]],
    responses: list[dict[str, Any]],
    timestamp: str,
    pricing_state: str,
    confidence_level: str,
    blocking_reasons: list[str],
) -> dict[str, Any]:
    line_item_prices: list[dict[str, Any]] = []
    decoration_prices: list[dict[str, Any]] = []
    pricing_receipt_refs: list[dict[str, Any]] = []
    subtotal_cents = 0

    response_map = {str(entry["line_item_id"]): entry for entry in responses}
    for item in line_items:
        response_entry = response_map.get(str(item.get("line_item_id")))
        if not response_entry:
            continue
        response = response_entry["response"]
        receipt = response.get("receipt") or {}
        total_cents = int(receipt.get("total_amount") or 0)
        quantity = int(item.get("quantity") or 0) or 1
        subtotal_cents += total_cents

        line_item_prices.append(
            {
                "line_item_id": item["line_item_id"],
                "estimate_id": response.get("estimate_id"),
                "receipt_id": receipt.get("receipt_id"),
                "quantity": quantity,
                "unit_price_cents": round(total_cents / quantity),
                "line_total_cents": total_cents,
                "unit_price": money_from_cents(round(total_cents / quantity)),
                "line_total": money_from_cents(total_cents),
                "confidence_level": ((response.get("confidence") or {}).get("level") or "low"),
                "pricing_authority_path": response.get("pricing_authority_path"),
                "pricing_source": response.get("pricing_source"),
            }
        )
        decoration_prices.append(
            {
                "line_item_id": item["line_item_id"],
                "estimate_id": response.get("estimate_id"),
                "receipt_id": receipt.get("receipt_id"),
                "line_items": copy.deepcopy(response.get("line_items") or []),
                "pricing_trace": copy.deepcopy(response.get("pricing_trace") or []),
                "customer_explanation": copy.deepcopy(response.get("customer_explanation") or {}),
            }
        )
        pricing_receipt_refs.append(
            {
                "line_item_id": item["line_item_id"],
                "estimate_id": response.get("estimate_id"),
                "receipt_id": receipt.get("receipt_id"),
                "pricing_authority_path": response.get("pricing_authority_path"),
                "requested_at_utc": response.get("requested_at_utc") or timestamp,
            }
        )

    totals = {
        "subtotal": money_from_cents(subtotal_cents),
        "tax": 0,
        "shipping": 0,
        "total": money_from_cents(subtotal_cents),
    }

    return {
        "snapshot_timestamp": timestamp,
        "pricing_snapshot_id": str(uuid.uuid4()),
        "pricing_state": pricing_state,
        "line_item_prices": line_item_prices,
        "decoration_prices": decoration_prices,
        "calculated_totals": totals,
        "pricing_receipt_refs": pricing_receipt_refs,
        "confidence_level": confidence_level,
        "blocking_reasons": blocking_reasons,
        "pricing_authority_path": "mint.quote.packet.price",
    }


def confidence_floor(levels: list[str], warning_cap: bool) -> str:
    resolved = [level if level in CONFIDENCE_ORDER else "low" for level in levels]
    if not resolved:
        return "none"
    floor = min(resolved, key=lambda level: CONFIDENCE_ORDER[level])
    if warning_cap and CONFIDENCE_ORDER[floor] > CONFIDENCE_ORDER["medium"]:
        return "medium"
    return floor


def pricing_warning_cap(gaps: list[dict[str, Any]]) -> bool:
    for gap in gaps:
        if gap.get("severity") != "warning":
            continue
        if gap.get("gap_type") in {"shipping_ambiguity", "pricing_policy_review"}:
            return True
    return False


def sync_confidence(packet: dict[str, Any], pricing_snapshot: dict[str, Any]) -> None:
    confidence = copy.deepcopy(packet.get("confidence") or {})
    customer_conf = str(confidence.get("customer_confidence") or "none")
    artwork_conf = str(confidence.get("artwork_confidence") or "none")
    stock_conf = str(confidence.get("stock_confidence") or "none")
    pricing_conf = str(pricing_snapshot.get("confidence_level") or "none")

    confidence["pricing_confidence"] = pricing_conf
    confidence["overall"] = overall_confidence(customer_conf, artwork_conf, stock_conf, pricing_conf, packet.get("open_gaps") or [])
    packet["confidence"] = confidence


def sync_state(packet: dict[str, Any], pricing_snapshot: dict[str, Any]) -> None:
    if packet.get("state") in TERMINAL_STATES:
        return

    pricing_state = str(pricing_snapshot.get("pricing_state") or "")
    blocking_gaps = [gap for gap in packet.get("open_gaps") or [] if gap.get("severity") == "blocking"]
    if pricing_state != "completed" or blocking_gaps:
        packet["state"] = "needs_input"
        return
    packet["state"] = "drafting"


def apply_validation_gap(gaps: list[dict[str, Any]], line_item: dict[str, Any], details: dict[str, Any], timestamp: str) -> None:
    label = describe_line_item(line_item)
    grouped: dict[str, list[str]] = {"supplier_unresolved": [], "decoration_unresolved": []}
    for field, message in details.items():
        bucket = "supplier_unresolved" if field in {"blanks_cost", "supplier_source"} else "decoration_unresolved"
        grouped[bucket].append(str(message))

    if grouped["supplier_unresolved"]:
        add_gap(
            gaps,
            "supplier_unresolved",
            f"Pricing validation failed for {label}: {'; '.join(grouped['supplier_unresolved'])}",
            "blocking",
            "Correct supplier_source or blank cost inputs before re-pricing",
            timestamp,
        )
    if grouped["decoration_unresolved"]:
        add_gap(
            gaps,
            "decoration_unresolved",
            f"Pricing validation failed for {label}: {'; '.join(grouped['decoration_unresolved'])}",
            "blocking",
            "Correct the decoration-specific pricing inputs before re-pricing",
            timestamp,
        )


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    spine_root = Path(os.environ.get("SPINE_ROOT") or script_dir.parent.parent.parent.parent)
    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (spine_root / "runtime/domain-state/mint/quote-packets"))
    index_file = Path(os.environ.get("MINT_QUOTE_PACKET_INDEX_FILE") or (spine_root / "runtime/domain-state/mint/quote-packets-index.yaml"))

    packet_file = packet_file_for_id(packets_dir, args.packet_id)
    if not packet_file.exists():
        fail(f"quote_packet not found: {args.packet_id}")

    packet = load_structured_file(packet_file) or {}
    if packet.get("state") in TERMINAL_STATES:
        stop(f"cannot price packet in terminal state {packet['state']}")

    line_items = [item for item in (packet.get("line_items") or []) if isinstance(item, dict)]
    if not line_items:
        fail("quote_packet has no line_items to price")

    timestamp = now_utc()
    capability_name = current_capability_name()

    gaps = prune_transient_pricing_gaps(packet.get("open_gaps") or [])
    sync_line_item_pricing_gaps(gaps, line_items, timestamp)
    blocking_reasons = pricing_blocking_reasons(gaps, line_items)

    responses: list[dict[str, Any]] = []
    pricing_state = "blocked_insufficient_inputs"
    confidence_level = "none"

    if blocking_reasons:
        pricing_snapshot = snapshot_from_successes(
            packet=packet,
            line_items=line_items,
            responses=responses,
            timestamp=timestamp,
            pricing_state=pricing_state,
            confidence_level=confidence_level,
            blocking_reasons=blocking_reasons,
        )
    else:
        api_key = resolve_pricing_api_key(spine_root)
        if not api_key:
            pricing_state = "api_key_unavailable"
            blocking_reasons = ["PRICING_API_KEY is unavailable for the governed packet pricing runtime"]
            pricing_snapshot = snapshot_from_successes(
                packet=packet,
                line_items=line_items,
                responses=responses,
                timestamp=timestamp,
                pricing_state=pricing_state,
                confidence_level=confidence_level,
                blocking_reasons=blocking_reasons,
            )
        else:
            base_url = canonical_pricing_base_url(spine_root)
            try:
                for item in line_items:
                    payload = pricing_request_payload(packet, item, timestamp)
                    response = post_pricing_request(base_url, api_key, payload, args.timeout_seconds)
                    responses.append({"line_item_id": item["line_item_id"], "response": response})
            except urlerror.HTTPError as exc:
                payload = exc.read().decode("utf-8") if exc.fp else ""
                try:
                    details = json.loads(payload or "{}")
                except json.JSONDecodeError:
                    details = {}

                if exc.code == 400:
                    pricing_state = "blocked_insufficient_inputs"
                    error_details = details.get("details") if isinstance(details, dict) else {}
                    if not isinstance(error_details, dict):
                        error_details = {}
                    apply_validation_gap(gaps, item, error_details, timestamp)
                    blocking_reasons = pricing_blocking_reasons(gaps, line_items) or [
                        f"Pricing validation failed for {describe_line_item(item)}",
                    ]
                elif exc.code in {401, 403}:
                    pricing_state = "api_key_unavailable"
                    blocking_reasons = ["Pricing service rejected the configured API key"]
                else:
                    pricing_state = "api_call_failed"
                    blocking_reasons = [f"Pricing service returned HTTP {exc.code} for {describe_line_item(item)}"]

                pricing_snapshot = snapshot_from_successes(
                    packet=packet,
                    line_items=line_items,
                    responses=responses,
                    timestamp=timestamp,
                    pricing_state=pricing_state,
                    confidence_level="low" if responses else "none",
                    blocking_reasons=blocking_reasons,
                )
            except urlerror.URLError as exc:
                pricing_state = "service_unavailable"
                blocking_reasons = [f"Pricing service unavailable: {exc.reason}"]
                pricing_snapshot = snapshot_from_successes(
                    packet=packet,
                    line_items=line_items,
                    responses=responses,
                    timestamp=timestamp,
                    pricing_state=pricing_state,
                    confidence_level="none",
                    blocking_reasons=blocking_reasons,
                )
            else:
                pricing_state = "completed"
                line_confidences = [str((entry["response"].get("confidence") or {}).get("level") or "low") for entry in responses]
                confidence_level = confidence_floor(line_confidences, pricing_warning_cap(gaps))
                pricing_snapshot = snapshot_from_successes(
                    packet=packet,
                    line_items=line_items,
                    responses=responses,
                    timestamp=timestamp,
                    pricing_state=pricing_state,
                    confidence_level=confidence_level,
                    blocking_reasons=[],
                )

    packet["pricing_snapshot"] = pricing_snapshot
    for item in line_items:
        item["pricing_snapshot_id"] = pricing_snapshot["pricing_snapshot_id"]
    packet["line_items"] = line_items
    packet["open_gaps"] = reset_gap_ids(gaps)
    packet["updated_at"] = timestamp
    packet["receipts"] = append_receipt(packet.get("receipts") or [], capability_name, timestamp)
    packet.pop("quote_draft_ref", None)
    packet.pop("payment_ref", None)

    sync_confidence(packet, pricing_snapshot)
    sync_state(packet, pricing_snapshot)
    if pricing_state == "completed" and packet.get("state") == "drafting":
        packet.pop("customer_message_draft", None)

    dump_yaml(packet_file, packet)
    update_index(index_file, packet, timestamp)

    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"state: {packet['state']}")
    print(f"pricing_state: {pricing_snapshot['pricing_state']}")
    print(f"pricing_snapshot_id: {pricing_snapshot['pricing_snapshot_id']}")
    print(f"priced_line_item_count: {len(pricing_snapshot.get('line_item_prices') or [])}")
    print(f"blocking_gap_count: {len([gap for gap in packet.get('open_gaps', []) if gap.get('severity') == 'blocking'])}")
    if pricing_snapshot.get("blocking_reasons"):
        print("blocking_reasons:")
        for reason in pricing_snapshot["blocking_reasons"]:
            print(f"  - {reason}")
    print(f"packet_file: {packet_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
