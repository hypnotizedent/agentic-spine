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
from urllib import request as urlrequest

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root
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
    resolve_service_base_url_with_fallback,
    sync_quote_readiness,
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
GARMENT_MARKUP_RATE = 0.30
BLANK_LINE_CODES = {"blank", "blanks"}


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

    return resolve_service_base_url_with_fallback(
        spine_root,
        "pricing-v2",
        "http://100.79.183.14:3700",
    )


def resolve_pricing_api_key(spine_root: Path) -> str:
    env_value = os.environ.get("PRICING_API_KEY", "").strip()
    if env_value:
        return env_value

    infisical_agent = spine_root / "ops/plugins/providers/bin/infisical-agent.sh"
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


def post_lane_matrix_request(base_url: str, api_key: str, payload: dict[str, Any], timeout_seconds: int) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8")
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/v1/pricing/lane-matrix",
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


def money_to_cents(value: Any) -> int:
    try:
        return round(float(value) * 100)
    except (TypeError, ValueError):
        return 0


def response_line_total_cents(entry: dict[str, Any]) -> int:
    total_amount = entry.get("total_amount")
    if total_amount not in (None, ""):
        return money_to_cents(total_amount)

    unit_amount = entry.get("unit_amount")
    quantity = entry.get("quantity")
    try:
        quantity_int = int(quantity)
    except Exception:
        quantity_int = 0
    if unit_amount not in (None, "") and quantity_int > 0:
        return money_to_cents(unit_amount) * quantity_int
    return 0


def response_tax_cents(response: dict[str, Any]) -> int:
    taxes = response.get("taxes")
    if isinstance(taxes, dict):
        return money_to_cents(taxes.get("total_amount"))
    return money_to_cents(taxes)


def slug_token(value: str) -> str:
    cleaned = "".join(ch.lower() if ch.isalnum() else "-" for ch in value.strip())
    collapsed = "-".join(bit for bit in cleaned.split("-") if bit)
    return collapsed or "lane"


def preferred_screen_print_size_key(location: str, line_item: dict[str, Any]) -> str | None:
    existing = str(line_item.get("screen_print_size_key") or "").strip().upper()
    if existing in {"A6", "A5", "A4", "A3"}:
        return existing

    normalized_location = location.strip().lower()
    if any(token in normalized_location for token in ("left chest", "left-chest", "right chest", "right-chest", "sleeve", "pocket", "cap", "hat", "nape")):
        return "A6"
    if any(token in normalized_location for token in ("oversize", "oversized", "full front", "full back", "jumbo")):
        return "A3"
    if normalized_location:
        return "A4"
    return None


def lane_payload_for_item(packet: dict[str, Any], line_item: dict[str, Any], timestamp: str) -> dict[str, Any]:
    method = str(line_item["decoration_method"])
    locations = [str(value).strip() for value in (line_item.get("print_locations") or []) if str(value).strip()]
    if not locations:
        placement = str(line_item.get("placement") or "").strip()
        if placement:
            locations = [placement]
    if not locations:
        locations = ["front"]

    lanes: list[dict[str, Any]] = []
    shared_graphic = copy.deepcopy(line_item.get("graphic_size_inches"))
    shared_size_tier = line_item.get("size_tier_label")
    single_location = len(locations) == 1

    for index, location in enumerate(locations, start=1):
        lane: dict[str, Any] = {
            "lane_id": f"{line_item['line_item_id']}__{slug_token(location)}__{index}",
            "item_type": method,
            "placement_label": location,
            "locations": [location],
            "colors": int(line_item.get("color_count") or 0),
            "color_count": int(line_item.get("color_count") or 0),
            "artwork_fingerprint_sha256": line_item.get("artwork_fingerprint_sha256"),
        }

        if method == "screen_print":
            lane["method_variant"] = line_item.get("method_variant")
            lane["underbase_needed"] = bool(line_item.get("underbase_needed"))
            preferred_key = preferred_screen_print_size_key(location, line_item)
            if preferred_key:
                lane["screen_print_size_key"] = preferred_key
            if single_location and shared_graphic:
                lane["graphic_size_inches"] = copy.deepcopy(shared_graphic)
            if single_location and shared_size_tier:
                lane["size_tier_label"] = shared_size_tier
        elif method == "embroidery":
            lane["stitch_count"] = int(line_item.get("stitch_count") or 0)
            lane["puff_mode"] = line_item.get("puff_mode")
            lane["thread_type"] = line_item.get("thread_type")
            lane["hoop_class"] = line_item.get("hoop_class")
            if line_item.get("garment_material"):
                lane["garment_material"] = line_item.get("garment_material")
            if line_item.get("curved_panel_cap") is not None:
                lane["curved_panel_cap"] = bool(line_item.get("curved_panel_cap"))
            if shared_graphic:
                lane["graphic_size_inches"] = copy.deepcopy(shared_graphic)
        elif method == "engraving":
            lane["material_class"] = line_item.get("material_class")
            if shared_graphic:
                lane["graphic_size_inches"] = copy.deepcopy(shared_graphic)
            if shared_size_tier:
                lane["size_tier_label"] = shared_size_tier
        elif method == "transfers":
            lane["transfer_type"] = line_item.get("transfer_type")
            lane["garment_family"] = line_item.get("garment_family")
            if shared_graphic:
                lane["graphic_size_inches"] = copy.deepcopy(shared_graphic)
            if shared_size_tier:
                lane["size_tier_label"] = shared_size_tier
        lanes.append(lane)

    payload: dict[str, Any] = {
        "correlation_id": f"{packet['quote_packet_id']}:{line_item['line_item_id']}",
        "request_timestamp_utc": timestamp,
        "customer_ref": customer_ref_string(packet) or str(packet.get("quote_packet_id") or "quote-packet"),
        "supplier_source": str(line_item["supplier_source"]),
        "blanks_cost": round(float(line_item["blanks_cost_cents"]) / 100, 2),
        "qty_options": [int(line_item["quantity"])],
        "setup_mode_options": [str(line_item.get("setup_mode") or "none")],
        "lanes": lanes,
    }

    garment_family = str(line_item.get("garment_family") or "").strip()
    if garment_family:
        payload["garment_family"] = garment_family
    garment_material = str(line_item.get("garment_material") or "").strip()
    if garment_material:
        payload["garment_material"] = garment_material
    return payload


def scenario_for_item(line_item: dict[str, Any], response: dict[str, Any]) -> dict[str, Any]:
    scenarios = [entry for entry in (response.get("scenarios") or []) if isinstance(entry, dict)]
    quantity = int(line_item.get("quantity") or 0)
    setup_mode = str(line_item.get("setup_mode") or "none")
    for scenario in scenarios:
        if int(scenario.get("qty") or 0) == quantity and str(scenario.get("setup_mode") or "") == setup_mode:
            return scenario
    if len(scenarios) == 1:
        return scenarios[0]
    return {}


def lane_breakdowns_for(item: dict[str, Any], response: dict[str, Any], quantity: int) -> list[dict[str, Any]]:
    scenario = scenario_for_item(item, response)
    lane_entries = [entry for entry in (scenario.get("lanes") or []) if isinstance(entry, dict)]
    results: list[dict[str, Any]] = []
    for lane in lane_entries:
        unit_amount = money_to_cents(lane.get("customer_unit_amount"))
        setup_total_cents = money_to_cents(lane.get("setup_total_amount"))
        production_unit_cents = money_to_cents(lane.get("production_unit_amount"))
        underbase_total_cents = money_to_cents(lane.get("underbase_total_amount"))
        total_cents = unit_amount * quantity
        results.append(
            {
                "lane_id": lane.get("lane_id"),
                "placement_label": lane.get("placement_label"),
                "pricing_key_type": lane.get("pricing_key_type"),
                "pricing_key": lane.get("pricing_key"),
                "screen_print_size_key": lane.get("screen_print_size_key"),
                "requested_method_variant": lane.get("requested_method_variant"),
                "workbook_base_variant": lane.get("workbook_base_variant"),
                "variant_pricing_mode": lane.get("variant_pricing_mode"),
                "customer_unit_cents": unit_amount,
                "customer_unit": money_from_cents(unit_amount),
                "customer_total_cents": total_cents,
                "customer_total": money_from_cents(total_cents),
                "production_unit_cents": production_unit_cents,
                "production_unit": money_from_cents(production_unit_cents),
                "setup_total_cents": setup_total_cents,
                "setup_total": money_from_cents(setup_total_cents),
                "underbase_total_cents": underbase_total_cents,
                "underbase_total": money_from_cents(underbase_total_cents),
                "receipt_id": lane.get("receipt_id"),
            }
        )
    return results


def pricing_breakdown_for_lane_matrix(item: dict[str, Any], response: dict[str, Any], quantity: int) -> dict[str, Any]:
    scenario = scenario_for_item(item, response)
    wholesale_blank_unit_cents = int(item.get("blanks_cost_cents") or 0)
    garment_markup_unit_cents = round(wholesale_blank_unit_cents * GARMENT_MARKUP_RATE)
    customer_garment_unit_cents = wholesale_blank_unit_cents + garment_markup_unit_cents
    customer_garment_total_cents = customer_garment_unit_cents * quantity

    lane_breakdowns = lane_breakdowns_for(item, response, quantity)
    imprint_total_cents = sum(int(entry.get("customer_total_cents") or 0) for entry in lane_breakdowns)
    imprint_unit_cents = round(imprint_total_cents / quantity) if quantity > 0 else 0
    customer_unit_cents = money_to_cents(scenario.get("customer_unit_amount"))
    if customer_unit_cents <= 0:
        customer_unit_cents = customer_garment_unit_cents + imprint_unit_cents
    customer_subtotal_cents = customer_unit_cents * quantity
    garment_markup_total_cents = garment_markup_unit_cents * quantity
    wholesale_blank_total_cents = wholesale_blank_unit_cents * quantity

    return {
        "wholesale_blank_unit_cents": wholesale_blank_unit_cents,
        "wholesale_blank_unit": money_from_cents(wholesale_blank_unit_cents),
        "wholesale_blank_total_cents": wholesale_blank_total_cents,
        "wholesale_blank_total": money_from_cents(wholesale_blank_total_cents),
        "garment_markup_unit_cents": garment_markup_unit_cents,
        "garment_markup_unit": money_from_cents(garment_markup_unit_cents),
        "garment_markup_total_cents": garment_markup_total_cents,
        "garment_markup_total": money_from_cents(garment_markup_total_cents),
        "imprint_unit_cents": imprint_unit_cents,
        "imprint_unit": money_from_cents(imprint_unit_cents),
        "imprint_total_cents": imprint_total_cents,
        "imprint_total": money_from_cents(imprint_total_cents),
        "customer_unit_cents": customer_unit_cents,
        "customer_unit": money_from_cents(customer_unit_cents),
        "customer_total_cents": customer_subtotal_cents,
        "customer_total": money_from_cents(customer_subtotal_cents),
        "tax_cents": 0,
        "tax": 0,
        "total_with_tax_cents": customer_subtotal_cents,
        "total_with_tax": money_from_cents(customer_subtotal_cents),
        "lane_breakdowns": lane_breakdowns,
    }


def pricing_breakdown_for(item: dict[str, Any], response: dict[str, Any], quantity: int) -> dict[str, Any]:
    response_subtotal_cents = 0
    response_blank_total_cents = 0
    imprint_total_cents = 0
    for entry in response.get("line_items") or []:
        if not isinstance(entry, dict):
            continue
        total_cents = response_line_total_cents(entry)
        response_subtotal_cents += total_cents
        code = str(entry.get("code") or "").strip().lower()
        if code in BLANK_LINE_CODES:
            response_blank_total_cents += total_cents
        else:
            imprint_total_cents += total_cents

    wholesale_blank_unit_cents = int(item.get("blanks_cost_cents") or 0)
    if wholesale_blank_unit_cents <= 0 and quantity > 0 and response_blank_total_cents > 0:
        wholesale_blank_unit_cents = round(response_blank_total_cents / quantity)

    garment_markup_unit_cents = round(wholesale_blank_unit_cents * GARMENT_MARKUP_RATE)
    customer_garment_unit_cents = wholesale_blank_unit_cents + garment_markup_unit_cents
    customer_garment_total_cents = customer_garment_unit_cents * quantity
    customer_subtotal_cents = customer_garment_total_cents + imprint_total_cents

    raw_tax_cents = response_tax_cents(response)
    effective_tax_rate = (raw_tax_cents / response_subtotal_cents) if response_subtotal_cents > 0 else 0
    customer_tax_cents = round(customer_subtotal_cents * effective_tax_rate)
    customer_total_cents = customer_subtotal_cents + customer_tax_cents

    imprint_unit_cents = round(imprint_total_cents / quantity) if quantity > 0 else 0
    customer_unit_cents = round(customer_subtotal_cents / quantity) if quantity > 0 else 0
    garment_markup_total_cents = garment_markup_unit_cents * quantity
    wholesale_blank_total_cents = wholesale_blank_unit_cents * quantity

    return {
        "wholesale_blank_unit_cents": wholesale_blank_unit_cents,
        "wholesale_blank_unit": money_from_cents(wholesale_blank_unit_cents),
        "wholesale_blank_total_cents": wholesale_blank_total_cents,
        "wholesale_blank_total": money_from_cents(wholesale_blank_total_cents),
        "garment_markup_unit_cents": garment_markup_unit_cents,
        "garment_markup_unit": money_from_cents(garment_markup_unit_cents),
        "garment_markup_total_cents": garment_markup_total_cents,
        "garment_markup_total": money_from_cents(garment_markup_total_cents),
        "imprint_unit_cents": imprint_unit_cents,
        "imprint_unit": money_from_cents(imprint_unit_cents),
        "imprint_total_cents": imprint_total_cents,
        "imprint_total": money_from_cents(imprint_total_cents),
        "customer_unit_cents": customer_unit_cents,
        "customer_unit": money_from_cents(customer_unit_cents),
        "customer_total_cents": customer_subtotal_cents,
        "customer_total": money_from_cents(customer_subtotal_cents),
        "tax_cents": customer_tax_cents,
        "tax": money_from_cents(customer_tax_cents),
        "total_with_tax_cents": customer_total_cents,
        "total_with_tax": money_from_cents(customer_total_cents),
    }


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
    tax_cents = 0

    response_map = {str(entry["line_item_id"]): entry for entry in responses}
    for item in line_items:
        response_entry = response_map.get(str(item.get("line_item_id")))
        if not response_entry:
            continue
        response = response_entry["response"]
        quantity = int(item.get("quantity") or 0) or 1
        response_mode = str(response_entry.get("response_mode") or "estimate")
        if response_mode == "lane_matrix":
            scenario = scenario_for_item(item, response)
            lane_breakdowns = lane_breakdowns_for(item, response, quantity)
            breakdown = pricing_breakdown_for_lane_matrix(item, response, quantity)
            receipt_id = None
            estimate_id = None
            pricing_source = "mint.pricing.lane_matrix"
            pricing_authority_path = "mint.pricing.lane_matrix"
            confidence_level_entry = "high"
            customer_explanation = {
                "lane_pricing_mode": "lane_matrix",
                "scenario_id": scenario.get("scenario_id"),
                "lane_count": len(lane_breakdowns),
                "size_tier_label": item.get("size_tier_label"),
            }
            line_items_payload = []
            pricing_trace = []
            requested_at_utc = timestamp
        else:
            receipt = response.get("receipt") or {}
            lane_breakdowns = []
            breakdown = pricing_breakdown_for(item, response, quantity)
            receipt_id = receipt.get("receipt_id")
            estimate_id = response.get("estimate_id")
            pricing_source = response.get("pricing_source")
            pricing_authority_path = response.get("pricing_authority_path")
            confidence_level_entry = ((response.get("confidence") or {}).get("level") or "low")
            customer_explanation = copy.deepcopy(response.get("customer_explanation") or {})
            line_items_payload = copy.deepcopy(response.get("line_items") or [])
            pricing_trace = copy.deepcopy(response.get("pricing_trace") or [])
            requested_at_utc = response.get("requested_at_utc") or timestamp
        subtotal_cents += int(breakdown["customer_total_cents"])
        tax_cents += int(breakdown["tax_cents"])

        line_item_prices.append(
            {
                "line_item_id": item["line_item_id"],
                "estimate_id": estimate_id,
                "receipt_id": receipt_id,
                "quantity": quantity,
                "unit_price_cents": breakdown["customer_unit_cents"],
                "line_total_cents": breakdown["customer_total_cents"],
                "unit_price": breakdown["customer_unit"],
                "line_total": breakdown["customer_total"],
                "pricing_breakdown": breakdown,
                "confidence_level": confidence_level_entry,
                "pricing_authority_path": pricing_authority_path,
                "pricing_source": pricing_source,
            }
        )
        decoration_prices.append(
            {
                "line_item_id": item["line_item_id"],
                "estimate_id": estimate_id,
                "receipt_id": receipt_id,
                "pricing_breakdown": breakdown,
                "line_items": line_items_payload,
                "pricing_trace": pricing_trace,
                "customer_explanation": customer_explanation,
                "lane_prices": lane_breakdowns,
            }
        )
        pricing_receipt_refs.append(
            {
                "line_item_id": item["line_item_id"],
                "estimate_id": estimate_id,
                "receipt_id": receipt_id,
                "pricing_authority_path": pricing_authority_path,
                "requested_at_utc": requested_at_utc,
                "lane_receipt_refs": [
                    {
                        "lane_id": lane.get("lane_id"),
                        "receipt_id": lane.get("receipt_id"),
                        "pricing_key": lane.get("pricing_key"),
                    }
                    for lane in lane_breakdowns
                ],
            }
        )

    totals = {
        "subtotal": money_from_cents(subtotal_cents),
        "tax": money_from_cents(tax_cents),
        "shipping": 0,
        "total": money_from_cents(subtotal_cents + tax_cents),
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
        "pricing_authority_path": "mint.pricing.lane_matrix",
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

    spine_root = resolve_spine_root(__file__)
    mint_root = resolve_mint_data_root(spine_root=spine_root, current_file=__file__)
    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (mint_root / "quote-packets"))
    index_file = Path(os.environ.get("MINT_QUOTE_PACKET_INDEX_FILE") or (mint_root / "quote-packets-index.yaml"))

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
                    payload = lane_payload_for_item(packet, item, timestamp)
                    response = post_lane_matrix_request(base_url, api_key, payload, args.timeout_seconds)
                    responses.append(
                        {
                            "line_item_id": item["line_item_id"],
                            "response_mode": "lane_matrix",
                            "response": response,
                        }
                    )
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
                line_confidences = []
                for entry in responses:
                    response_mode = str(entry.get("response_mode") or "estimate")
                    if response_mode == "lane_matrix":
                        line_confidences.append("high")
                    else:
                        line_confidences.append(str((entry["response"].get("confidence") or {}).get("level") or "low"))
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
    readiness = sync_quote_readiness(packet)

    dump_yaml(packet_file, packet)
    update_index(index_file, packet, timestamp)

    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"state: {packet['state']}")
    print(f"pricing_state: {pricing_snapshot['pricing_state']}")
    print(f"quote_readiness_state: {readiness['state']}")
    print(f"quote_next_step: {readiness['next_step']}")
    print(f"pricing_snapshot_id: {pricing_snapshot['pricing_snapshot_id']}")
    print(f"priced_line_item_count: {len(pricing_snapshot.get('line_item_prices') or [])}")
    print(f"blocking_gap_count: {len([gap for gap in packet.get('open_gaps', []) if gap.get('severity') == 'blocking'])}")
    for price_entry in (pricing_snapshot.get("line_item_prices") or [])[:3]:
        breakdown = price_entry.get("pricing_breakdown") or {}
        line_item_id = price_entry.get("line_item_id") or "unknown"
        print(
            "line_item_price:"
            f" {line_item_id}"
            f" wholesale_blank={breakdown.get('wholesale_blank_unit')}"
            f" garment_markup={breakdown.get('garment_markup_unit')}"
            f" imprint={breakdown.get('imprint_unit')}"
            f" customer_unit={price_entry.get('unit_price')}"
            f" customer_total={price_entry.get('line_total')}"
        )
        for lane in (breakdown.get("lane_breakdowns") or [])[:8]:
            if not isinstance(lane, dict):
                continue
            print(
                "lane_price:"
                f" {line_item_id}"
                f" lane_id={lane.get('lane_id') or ''}"
                f" placement={lane.get('placement_label') or ''}"
                f" pricing_key={lane.get('pricing_key') or ''}"
                f" customer_unit={lane.get('customer_unit')}"
                f" receipt_id={lane.get('receipt_id') or ''}"
            )
    if pricing_snapshot.get("blocking_reasons"):
        print("blocking_reasons:")
        for reason in pricing_snapshot["blocking_reasons"]:
            print(f"  - {reason}")
    print(f"packet_file: {packet_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
