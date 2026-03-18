#!/usr/bin/env python3
"""Persist governed quote-estimate recommendations before exact production pricing."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sys
import uuid
from pathlib import Path
from typing import Any
from urllib import error as urlerror

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root
from quote_packet_normalize import (
    append_receipt,
    dump_yaml,
    fail,
    load_structured_file,
    now_utc,
    sync_quote_readiness,
    update_index,
)
from quote_packet_price import (
    canonical_pricing_base_url,
    money_from_cents,
    post_pricing_request,
    pricing_request_payload,
    resolve_pricing_api_key,
)


TERMINAL_STATES = {"sent", "paid", "closed"}
SUPPORTED_PUBLIC_METHODS = {"screen_print", "embroidery", "transfer"}
SUPPORTED_ESTIMATOR_METHODS = {
    "screen_print": "screen_print",
    "embroidery": "embroidery",
    "transfer": "transfers",
}
METHOD_NAME_REMAP = {"transfers": "transfer"}
LIGHT_COLOR_CACHE_KEY = "light"
DARK_COLOR_CACHE_KEY = "dark"
COLOR_TOKEN_RE = re.compile(r"[a-z0-9]+")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-estimate",
        description=(
            "Create estimate-safe quote recommendations from a sourced quote_packet "
            "without mutating production-final pricing truth."
        ),
    )
    parser.add_argument("packet_id", help="quote_packet_id to estimate")
    parser.add_argument("--timeout-seconds", type=int, default=45, help="HTTP timeout for pricing requests")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_ESTIMATE_CAPABILITY_NAME") or "mint.quote.packet.estimate"


def packet_file_for_id(packets_dir: Path, packet_id: str) -> Path:
    return packets_dir / f"quote_packet_{packet_id}.yaml"


def resolve_code_root() -> Path:
    return Path(__file__).resolve().parents[5]


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


def normalize_text(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def normalize_lower(value: Any) -> str:
    return normalize_text(value).lower()


def attachment_token_set(values: list[str]) -> set[str]:
    tokens: set[str] = set()
    for value in values:
        if not value:
            continue
        tokens.add(normalize_lower(value))
    return tokens


def resolve_policy(spine_root: Path) -> dict[str, Any]:
    override = str(os.environ.get("MINT_QUOTE_PACKET_ESTIMATE_POLICY_CONTRACT") or "").strip()
    path = Path(override).expanduser().resolve() if override else (spine_root / "ops/bindings/mint.quote.packet.estimate.policy.contract.yaml")
    if not path.is_file() and not override:
        path = resolve_code_root() / "ops/bindings/mint.quote.packet.estimate.policy.contract.yaml"
    if not path.is_file():
        fail(f"quote estimate policy contract not found: {path}")
    payload = load_structured_file(path)
    if not isinstance(payload, dict):
        fail(f"quote estimate policy contract invalid: {path}")
    payload["path"] = str(path)
    return payload


def line_text(packet: dict[str, Any], item: dict[str, Any]) -> str:
    parts = [
        item.get("description"),
        item.get("operator_notes"),
        packet.get("operator_notes"),
    ]
    for ref in packet.get("source_refs") or []:
        if isinstance(ref, dict):
            parts.append(ref.get("summary"))
    return "\n".join(normalize_text(part) for part in parts if normalize_text(part))


def customer_declared_text(packet: dict[str, Any], item: dict[str, Any]) -> str:
    parts = [
        item.get("description"),
        item.get("operator_notes"),
        packet.get("operator_notes"),
    ]
    return "\n".join(normalize_text(part) for part in parts if normalize_text(part))


def describe_line_item(item: dict[str, Any]) -> str:
    return str(item.get("description") or item.get("product_type") or item.get("line_item_id") or "line item")


def contains_any(text: str, markers: list[str]) -> bool:
    lowered = normalize_lower(text)
    return any(marker in lowered for marker in markers)


def infer_method(packet: dict[str, Any], item: dict[str, Any], policy: dict[str, Any]) -> tuple[str, str, list[str], int]:
    reasons: list[str] = []
    method_rules = dict(policy.get("method_rules") or {})
    qty = int(item.get("quantity") or 0)
    text = line_text(packet, item)

    explicit_method = str(item.get("decoration_method") or "").strip()
    if explicit_method:
        public_method = METHOD_NAME_REMAP.get(explicit_method, explicit_method)
        reasons.append(f"explicit_line_item_method:{explicit_method}")
        return public_method, "explicit", reasons, 3

    if contains_any(text, list(method_rules.get("embroidery_markers") or [])):
        reasons.append("keyword:embroidery")
        return "embroidery", "strong_inference", reasons, 2
    if contains_any(text, list(method_rules.get("transfer_markers") or [])):
        reasons.append("keyword:transfer")
        return "transfer", "strong_inference", reasons, 2
    if contains_any(text, list(method_rules.get("dtg_markers") or [])) and qty and qty <= int(method_rules.get("dtg_max_qty") or 24):
        reasons.append("keyword:dtg")
        return "dtg", "strong_inference", reasons, 2
    if item.get("print_locations") and qty >= int(method_rules.get("screen_print_min_qty") or 24):
        reasons.append("policy:screen_print_min_qty")
        return "screen_print", "strong_inference", reasons, 2
    if item.get("print_locations"):
        reasons.append("fallback:print_locations_present")
        return "screen_print", "policy_default", reasons, 1
    reasons.append("missing_decoration_signal")
    return "", "missing", reasons, -3


def explicit_graphic_size(item: dict[str, Any]) -> bool:
    graphic = item.get("graphic_size_inches")
    if not isinstance(graphic, dict):
        return False
    return isinstance(graphic.get("width_in"), (int, float)) and isinstance(graphic.get("height_in"), (int, float))


def choose_size_profile(packet: dict[str, Any], item: dict[str, Any], policy: dict[str, Any]) -> tuple[str, dict[str, Any], list[str], int]:
    profiles = dict((policy.get("defaults") or {}).get("size_profiles") or {})
    reasons: list[str] = []

    if explicit_graphic_size(item) and str(item.get("size_tier_label") or "").strip():
        reasons.append("explicit_line_item_size")
        return (
            "explicit",
            {
                "size_tier_label": str(item["size_tier_label"]),
                "graphic_size_inches": copy.deepcopy(item["graphic_size_inches"]),
            },
            reasons,
            3,
        )

    locations = [normalize_lower(location) for location in (item.get("print_locations") or []) if normalize_text(location)]
    text = line_text(packet, item)

    if any(location in {"back", "full_back", "full front", "full_front"} for location in locations):
        reasons.append("location:full_back_or_front")
        return "standard_front_or_back", copy.deepcopy(profiles.get("standard_front_or_back") or {}), reasons, 2
    if any(location in {"front"} for location in locations):
        if any(marker in normalize_lower(text) for marker in ("left chest", "front chest", "small logo on front chest")):
            reasons.append("text:left_chest")
            return "left_chest_standard", copy.deepcopy(profiles.get("left_chest_standard") or {}), reasons, 2
        reasons.append("location:front")
        return "standard_front_or_back", copy.deepcopy(profiles.get("standard_front_or_back") or {}), reasons, 2
    if any("sleeve" in location for location in locations) or "sleeve" in normalize_lower(text):
        reasons.append("location:sleeve")
        return "sleeve_standard", copy.deepcopy(profiles.get("sleeve_standard") or {}), reasons, 2
    if any(marker in normalize_lower(text) for marker in ("left chest", "front chest")):
        reasons.append("text:left_chest")
        return "left_chest_standard", copy.deepcopy(profiles.get("left_chest_standard") or {}), reasons, 2
    reasons.append("policy_default:standard_front_or_back")
    return "standard_front_or_back", copy.deepcopy(profiles.get("standard_front_or_back") or {}), reasons, 1


def count_named_colors(text: str, policy: dict[str, Any]) -> int:
    color_tokens = set(COLOR_TOKEN_RE.findall(normalize_lower(text)))
    named = {
        token
        for token in (policy.get("artwork_rules") or {}).get("named_color_tokens") or []
        if normalize_lower(token) in color_tokens
    }
    return len(named)


def infer_color_count(packet: dict[str, Any], item: dict[str, Any], public_method: str, policy: dict[str, Any]) -> tuple[int | None, list[str], int]:
    reasons: list[str] = []
    explicit = item.get("color_count")
    if isinstance(explicit, int) and explicit > 0:
        reasons.append("explicit_line_item_color_count")
        return explicit, reasons, 3

    text = line_text(packet, item)
    artwork_rules = dict(policy.get("artwork_rules") or {})
    named_count = count_named_colors(text, policy)
    lowered = normalize_lower(text)

    if public_method == "embroidery":
        if named_count > 0:
            reasons.append(f"named_colors:{named_count}")
            return max(1, min(named_count, 6)), reasons, 2
        reasons.append("default_embroidery_logo_color_count")
        return 1, reasons, 1

    if contains_any(lowered, list(artwork_rules.get("photo_markers") or [])):
        reasons.append("artwork_marker:photo_or_full_color")
        return 4, reasons, 2
    if contains_any(lowered, list(artwork_rules.get("complex_graphic_markers") or [])):
        reasons.append("artwork_marker:complex_graphic")
        return 4, reasons, 2
    if named_count > 0:
        reasons.append(f"named_colors:{named_count}")
        return max(1, min(named_count, 6)), reasons, 2
    if contains_any(lowered, list(artwork_rules.get("simple_logo_markers") or [])):
        reasons.append("artwork_marker:simple_logo")
        return 1, reasons, 2
    reasons.append("policy_default:two_color")
    return 2, reasons, 1


def garment_color_state(item: dict[str, Any], policy: dict[str, Any]) -> str:
    color = normalize_lower(garment_color_text(item))
    if not color:
        return "unknown"
    light_tokens = attachment_token_set([str(item) for item in ((policy.get("garment_color_rules") or {}).get("light_tokens") or [])])
    dark_tokens = attachment_token_set([str(item) for item in ((policy.get("garment_color_rules") or {}).get("dark_tokens") or [])])
    if any(token in color for token in light_tokens):
        return LIGHT_COLOR_CACHE_KEY
    if any(token in color for token in dark_tokens):
        return DARK_COLOR_CACHE_KEY
    return "unknown"


def garment_color_text(item: dict[str, Any]) -> str:
    description = normalize_text(item.get("description"))
    if description:
        match = re.search(r"[–-]\s*([A-Za-z][A-Za-z0-9 /-]+)$", description)
        if match:
            return match.group(1).strip()
    explicit_color = normalize_text(item.get("color"))
    if explicit_color:
        return explicit_color
    notes = normalize_text(item.get("operator_notes"))
    color_match = re.search(r"(?i)\bcolor:\s*([A-Za-z][A-Za-z0-9 /-]+)", notes)
    if color_match:
        return color_match.group(1).strip()
    return ""


def infer_underbase(item: dict[str, Any], public_method: str, color_count: int | None, policy: dict[str, Any]) -> tuple[bool | None, list[str], int]:
    reasons: list[str] = []
    explicit = item.get("underbase_needed")
    if isinstance(explicit, bool):
        reasons.append("explicit_line_item_underbase")
        return explicit, reasons, 3
    if public_method not in {"screen_print", "transfer"}:
        return None, reasons, 0

    color_state = garment_color_state(item, policy)
    if color_state == LIGHT_COLOR_CACHE_KEY:
        reasons.append("garment_color:light")
        return False, reasons, 2
    if color_state == DARK_COLOR_CACHE_KEY:
        reasons.append("garment_color:dark")
        return True, reasons, 2
    if isinstance(color_count, int) and color_count >= 4:
        reasons.append("policy_default:unknown_garment_multicolor")
        return True, reasons, 1
    reasons.append("policy_default:no_underbase")
    return False, reasons, 1


def infer_setup_mode(packet: dict[str, Any], item: dict[str, Any], policy: dict[str, Any]) -> tuple[str, list[str], int]:
    reasons: list[str] = []
    explicit = str(item.get("setup_mode") or "").strip()
    if explicit:
        reasons.append("explicit_line_item_setup_mode")
        return explicit, reasons, 3

    text = customer_declared_text(packet, item)
    reorder_markers = [str(marker) for marker in ((policy.get("method_rules") or {}).get("reorder_markers") or [])]
    if contains_any(text, reorder_markers):
        reasons.append("reorder_marker")
        return "re_setup", reasons, 2

    historical_refs = [ref for ref in (packet.get("source_refs") or []) if isinstance(ref, dict) and ref.get("ref_type") == "historical_quote"]
    if historical_refs and contains_any(text, ["same logo", "same art", "same design", "reuse"]):
        reasons.append("historical_quote_plus_reuse_marker")
        return "re_setup", reasons, 2

    reasons.append("policy_default:new_setup")
    return str(((policy.get("defaults") or {}).get("setup_mode")) or "new_setup"), reasons, 1


def infer_lead_time_days(item: dict[str, Any], policy: dict[str, Any]) -> tuple[int | None, list[str], int]:
    reasons: list[str] = []
    explicit = item.get("lead_time_days")
    if isinstance(explicit, int) and explicit > 0:
        reasons.append("explicit_line_item_lead_time")
        return explicit, reasons, 3
    reasons.append("policy_default:lead_time_days")
    return int(((policy.get("defaults") or {}).get("lead_time_days")) or 7), reasons, 1


def infer_embroidery_fields(size_profile_name: str, policy: dict[str, Any]) -> tuple[dict[str, Any], list[str], int]:
    defaults = dict(((policy.get("defaults") or {}).get("embroidery")) or {})
    reasons: list[str] = []
    if size_profile_name == "left_chest_standard":
        stitch_count = int(defaults.get("chest_stitch_count") or 8000)
        reasons.append("policy_default:embroidery_chest_stitch_count")
    else:
        stitch_count = int(defaults.get("standard_stitch_count") or 12000)
        reasons.append("policy_default:embroidery_standard_stitch_count")
    hoop_class = "flat_hoop"
    if size_profile_name == "sleeve_standard":
        hoop_class = "sleeve_hoop"
        reasons.append("policy_default:sleeve_hoop")
    else:
        reasons.append("policy_default:flat_hoop")
    return (
        {
            "stitch_count": stitch_count,
            "thread_type": str(defaults.get("default_thread_type") or "standard"),
            "puff_mode": str(defaults.get("default_puff_mode") or "flat"),
            "hoop_class": hoop_class,
        },
        reasons,
        1,
    )


def recommend_line_item(packet: dict[str, Any], item: dict[str, Any], policy: dict[str, Any]) -> dict[str, Any]:
    status_model = dict(policy.get("status_model") or {})
    missing_clarifications: list[str] = []
    assumptions: list[str] = []
    confidence_score = 0

    public_method, method_mode, method_reasons, method_score = infer_method(packet, item, policy)
    confidence_score += method_score
    assumptions.extend(method_reasons)
    if not public_method:
        missing_clarifications.append("recommended print method")

    size_profile_name, size_profile, size_reasons, size_score = choose_size_profile(packet, item, policy)
    confidence_score += size_score
    assumptions.extend(size_reasons)

    color_count, color_reasons, color_score = infer_color_count(packet, item, public_method, policy)
    confidence_score += color_score
    assumptions.extend(color_reasons)

    underbase_needed, underbase_reasons, underbase_score = infer_underbase(item, public_method, color_count, policy)
    confidence_score += underbase_score
    assumptions.extend(underbase_reasons)

    setup_mode, setup_reasons, setup_score = infer_setup_mode(packet, item, policy)
    confidence_score += setup_score
    assumptions.extend(setup_reasons)

    lead_time_days, lead_reasons, lead_score = infer_lead_time_days(item, policy)
    confidence_score += lead_score
    assumptions.extend(lead_reasons)

    qty = int(item.get("quantity") or 0)
    if qty <= 0:
        missing_clarifications.append("quantity")

    blanks_cost_cents = item.get("blanks_cost_cents")
    if not isinstance(blanks_cost_cents, int) or blanks_cost_cents <= 0:
        missing_clarifications.append("blank cost")

    supplier_source = str(item.get("supplier_source") or "").strip()
    if not supplier_source:
        missing_clarifications.append("supplier source")

    print_locations = copy.deepcopy(item.get("print_locations") or [])
    if not print_locations:
        missing_clarifications.append("print locations")

    estimator_method = SUPPORTED_ESTIMATOR_METHODS.get(public_method, "")
    if public_method and public_method not in SUPPORTED_PUBLIC_METHODS:
        missing_clarifications.append(f"unsupported quote estimate method: {public_method}")
    if public_method == "dtg":
        missing_clarifications.append("governed DTG estimate runtime is not implemented yet")
        confidence_score -= 3

    quote_safe_now = not missing_clarifications
    estimate_status = "estimate_ready"
    assumed_fields: list[str] = []

    if method_mode != "explicit":
        assumed_fields.append("recommended_method")
    if size_profile_name != "explicit":
        assumed_fields.extend(["graphic_size_inches", "size_tier_label"])
    if not isinstance(item.get("color_count"), int):
        assumed_fields.append("color_count")
    if not isinstance(item.get("lead_time_days"), int):
        assumed_fields.append("lead_time_days")
    if not str(item.get("setup_mode") or "").strip():
        assumed_fields.append("setup_mode")
    if public_method == "screen_print":
        if not str(item.get("method_variant") or "").strip():
            assumed_fields.append("method_variant")
        if not isinstance(item.get("underbase_needed"), bool):
            assumed_fields.append("underbase_needed")
    if public_method == "embroidery":
        if not isinstance(item.get("stitch_count"), int):
            assumed_fields.append("stitch_count")
        if not str(item.get("thread_type") or "").strip():
            assumed_fields.append("thread_type")
        if not str(item.get("puff_mode") or "").strip():
            assumed_fields.append("puff_mode")
        if not str(item.get("hoop_class") or "").strip():
            assumed_fields.append("hoop_class")
    if public_method == "transfer":
        if not str(item.get("transfer_type") or "").strip():
            assumed_fields.append("transfer_type")
        if not str(item.get("garment_family") or "").strip():
            assumed_fields.append("garment_family")

    exact_line_item: dict[str, Any] | None = None
    decoration_profile: dict[str, Any] = {
        "print_locations": print_locations,
        "size_profile": size_profile_name,
        "graphic_size_inches": copy.deepcopy(size_profile.get("graphic_size_inches") or {}),
        "size_tier_label": size_profile.get("size_tier_label"),
        "color_count": color_count,
        "lead_time_days": lead_time_days,
        "setup_mode": setup_mode,
    }
    if quote_safe_now and estimator_method:
        exact_line_item = {
            "line_item_id": item["line_item_id"],
            "product_type": item.get("product_type"),
            "description": item.get("description"),
            "quantity": qty,
            "decoration_method": estimator_method,
            "color_count": color_count,
            "print_locations": print_locations,
            "blanks_cost_cents": blanks_cost_cents,
            "supplier_source": supplier_source,
            "lead_time_days": lead_time_days,
            "graphic_size_inches": copy.deepcopy(size_profile.get("graphic_size_inches") or {}),
            "size_tier_label": size_profile.get("size_tier_label"),
            "setup_mode": setup_mode,
            "supplier_code": item.get("supplier_code"),
            "supplier_sku": item.get("supplier_sku"),
            "inventory_as_of_utc": item.get("inventory_as_of_utc"),
            "artwork_fingerprint_sha256": item.get("artwork_fingerprint_sha256"),
            "garment_family": item.get("garment_family") or item.get("product_type") or "",
        }

        if public_method == "screen_print":
            exact_line_item["method_variant"] = str(item.get("method_variant") or ((policy.get("defaults") or {}).get("screen_print_method_variant")) or "standard")
            exact_line_item["underbase_needed"] = bool(underbase_needed)
            decoration_profile["method_variant"] = exact_line_item["method_variant"]
            decoration_profile["underbase_needed"] = bool(underbase_needed)
        elif public_method == "embroidery":
            embroidery_defaults, embroidery_reasons, embroidery_score = infer_embroidery_fields(size_profile_name, policy)
            assumptions.extend(embroidery_reasons)
            confidence_score += embroidery_score
            exact_line_item.update(embroidery_defaults)
            decoration_profile.update(copy.deepcopy(embroidery_defaults))
        elif public_method == "transfer":
            exact_line_item["transfer_type"] = str(item.get("transfer_type") or ((policy.get("defaults") or {}).get("transfer_type")) or "dtf")
            decoration_profile["transfer_type"] = exact_line_item["transfer_type"]
            if underbase_needed is not None:
                decoration_profile["underbase_needed"] = bool(underbase_needed)

    if not quote_safe_now:
        estimate_status = "clarification_needed"
    elif assumed_fields:
        estimate_status = "production_only_exactness_missing"

    thresholds = dict(((policy.get("confidence_rules") or {}).get("thresholds")) or {})
    if confidence_score >= int(thresholds.get("high") or 8):
        confidence_level = "high"
    elif confidence_score >= int(thresholds.get("medium") or 5):
        confidence_level = "medium"
    else:
        confidence_level = "low"

    estimate_profile: dict[str, Any] = {
        "recommended_method": public_method or None,
        "quote_safe_now": status_model.get(estimate_status, {}).get("quote_safe_now", quote_safe_now),
        "estimate_status": estimate_status,
        "confidence_level": confidence_level,
        "blank_cost_cents": blanks_cost_cents if isinstance(blanks_cost_cents, int) else None,
        "blank_cost": money_from_cents(blanks_cost_cents) if isinstance(blanks_cost_cents, int) else None,
        "estimated_decoration_profile": decoration_profile,
        "assumptions": assumptions,
        "assumed_fields": assumed_fields,
        "missing_clarifications": missing_clarifications,
        "estimate_basis": {
            "method_mode": method_mode,
            "size_profile": size_profile_name,
        },
    }

    estimate_profile["exact_pricing_method"] = estimator_method or None
    estimate_profile["pricing_line_item"] = exact_line_item
    return estimate_profile


def line_item_totals(entry: dict[str, Any], response: dict[str, Any]) -> dict[str, Any]:
    receipt = response.get("receipt") or {}
    qty = int(entry.get("quantity") or 0) or 1
    blank_total_dollars = 0.0
    if isinstance(entry.get("blank_cost_cents"), int):
        blank_total_dollars = round((int(entry["blank_cost_cents"]) / 100.0) * qty, 2)

    candidate_totals: list[float] = []
    raw_line_total = 0.0
    for row in response.get("line_items") or []:
        if not isinstance(row, dict):
            continue
        try:
            raw_line_total += float(row.get("total_amount") or 0)
        except (TypeError, ValueError):
            continue
    if raw_line_total > 0:
        candidate_totals.append(raw_line_total if raw_line_total >= blank_total_dollars else raw_line_total / 100.0)

    try:
        receipt_total = float(receipt.get("total_amount") or 0)
    except (TypeError, ValueError):
        receipt_total = 0.0
    if receipt_total > 0:
        candidate_totals.append(receipt_total if receipt_total >= blank_total_dollars else receipt_total / 100.0)

    total_dollars = candidate_totals[0] if candidate_totals else 0.0
    total_cents = int(round(total_dollars * 100))
    unit_cents = round(total_cents / qty)
    return {
        "quantity": qty,
        "estimated_unit_price_cents": unit_cents,
        "estimated_unit_price": money_from_cents(unit_cents),
        "estimated_line_total_cents": total_cents,
        "estimated_line_total": money_from_cents(total_cents),
    }


def snapshot_confidence(line_item_estimates: list[dict[str, Any]]) -> str:
    order = {"none": 0, "low": 1, "medium": 2, "high": 3}
    levels = [str(entry.get("confidence_level") or "none") for entry in line_item_estimates if entry.get("estimate_status") != "clarification_needed"]
    if not levels:
        return "none"
    return min(levels, key=lambda level: order.get(level, 0))


def build_snapshot(
    packet: dict[str, Any],
    line_item_estimates: list[dict[str, Any]],
    timestamp: str,
    estimate_state: str,
    blocking_reasons: list[str],
) -> dict[str, Any]:
    subtotal_cents = sum(int(entry.get("estimated_line_total_cents") or 0) for entry in line_item_estimates)
    return {
        "snapshot_timestamp": timestamp,
        "estimate_snapshot_id": str(uuid.uuid4()),
        "estimate_state": estimate_state,
        "line_item_estimates": line_item_estimates,
        "calculated_totals": {
            "subtotal": money_from_cents(subtotal_cents),
            "tax": 0,
            "shipping": 0,
            "total": money_from_cents(subtotal_cents),
        },
        "estimate_receipt_refs": [
            {
                "line_item_id": entry["line_item_id"],
                "estimate_id": entry.get("estimate_id"),
                "receipt_id": entry.get("receipt_id"),
                "pricing_authority_path": entry.get("pricing_authority_path"),
                "requested_at_utc": entry.get("requested_at_utc") or timestamp,
            }
            for entry in line_item_estimates
            if entry.get("estimate_id") or entry.get("receipt_id")
        ],
        "confidence_level": snapshot_confidence(line_item_estimates),
        "blocking_reasons": blocking_reasons,
        "quote_safe_line_item_count": len([entry for entry in line_item_estimates if entry.get("quote_safe_now")]),
        "clarification_needed_count": len([entry for entry in line_item_estimates if entry.get("estimate_status") == "clarification_needed"]),
        "estimate_authority_path": "mint.quote.packet.estimate",
    }


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
        stop(f"cannot estimate packet in terminal state {packet['state']}")

    line_items = [item for item in (packet.get("line_items") or []) if isinstance(item, dict)]
    if not line_items:
        fail("quote_packet has no line_items to estimate")

    policy = resolve_policy(spine_root)
    timestamp = now_utc()
    capability_name = current_capability_name()

    recommended = [recommend_line_item(packet, item, policy) for item in line_items]
    estimate_state = "completed"
    blocking_reasons: list[str] = []
    line_item_estimates: list[dict[str, Any]] = []
    successful_count = 0

    api_key = resolve_pricing_api_key(spine_root)
    base_url = canonical_pricing_base_url(spine_root)
    estimator_available = bool(api_key)
    service_failure: str = ""

    for item, recommendation in zip(line_items, recommended):
        entry = {
            "line_item_id": item["line_item_id"],
            "description": item.get("description"),
            "recommended_method": recommendation.get("recommended_method"),
            "exact_pricing_method": recommendation.get("exact_pricing_method"),
            "quote_safe_now": recommendation.get("quote_safe_now"),
            "estimate_status": recommendation.get("estimate_status"),
            "confidence_level": recommendation.get("confidence_level"),
            "blank_cost_cents": recommendation.get("blank_cost_cents"),
            "blank_cost": recommendation.get("blank_cost"),
            "estimated_decoration_profile": copy.deepcopy(recommendation.get("estimated_decoration_profile") or {}),
            "assumptions": copy.deepcopy(recommendation.get("assumptions") or []),
            "assumed_fields": copy.deepcopy(recommendation.get("assumed_fields") or []),
            "missing_clarifications": copy.deepcopy(recommendation.get("missing_clarifications") or []),
        }

        pricing_line_item = recommendation.get("pricing_line_item")
        if not recommendation.get("quote_safe_now"):
            blocking_reasons.append(f"{describe_line_item(item)} still needs clarification: {', '.join(entry['missing_clarifications'])}")
            line_item_estimates.append(entry)
            continue
        if not pricing_line_item:
            blocking_reasons.append(f"{describe_line_item(item)} does not have a supported estimate method yet")
            entry["estimate_status"] = "clarification_needed"
            entry["quote_safe_now"] = False
            line_item_estimates.append(entry)
            continue
        if not estimator_available:
            estimate_state = "api_key_unavailable"
            service_failure = "PRICING_API_KEY is unavailable for governed quote estimates"
            line_item_estimates.append(entry)
            continue

        try:
            payload = pricing_request_payload(packet, pricing_line_item, timestamp)
            response = post_pricing_request(base_url, api_key, payload, args.timeout_seconds)
        except urlerror.HTTPError as exc:
            estimate_state = "blocked_insufficient_inputs" if exc.code == 400 else "api_call_failed"
            detail = exc.read().decode("utf-8") if exc.fp else ""
            service_failure = f"Pricing estimate service returned HTTP {exc.code} for {describe_line_item(item)}"
            if detail:
                service_failure = f"{service_failure}: {detail}"
            line_item_estimates.append(entry)
            continue
        except urlerror.URLError as exc:
            estimate_state = "service_unavailable"
            service_failure = f"Pricing estimate service unavailable: {exc.reason}"
            line_item_estimates.append(entry)
            continue

        receipt = response.get("receipt") or {}
        entry.update(line_item_totals(pricing_line_item, response))
        entry["estimate_id"] = response.get("estimate_id")
        entry["receipt_id"] = receipt.get("receipt_id")
        entry["requested_at_utc"] = response.get("requested_at_utc") or timestamp
        entry["pricing_authority_path"] = response.get("pricing_authority_path")
        entry["pricing_source"] = response.get("pricing_source")
        entry["customer_explanation"] = copy.deepcopy(response.get("customer_explanation") or {})
        line_item_estimates.append(entry)
        successful_count += 1

    if service_failure:
        blocking_reasons.append(service_failure)

    if estimate_state not in {"api_key_unavailable", "service_unavailable", "api_call_failed"}:
        if successful_count == len(line_items):
            estimate_state = "completed"
        elif successful_count > 0:
            estimate_state = "partial"
        else:
            estimate_state = "blocked_insufficient_inputs"

    snapshot = build_snapshot(packet, line_item_estimates, timestamp, estimate_state, blocking_reasons)
    packet["estimate_snapshot"] = snapshot
    packet["updated_at"] = timestamp
    packet["receipts"] = append_receipt(packet.get("receipts") or [], capability_name, timestamp)

    confidence = copy.deepcopy(packet.get("confidence") or {})
    confidence["estimate_confidence"] = snapshot.get("confidence_level") or "none"
    packet["confidence"] = confidence
    readiness = sync_quote_readiness(packet)

    dump_yaml(packet_file, packet)
    update_index(index_file, packet, timestamp)

    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"state: {packet.get('state')}")
    print(f"estimate_state: {snapshot['estimate_state']}")
    print(f"quote_readiness_state: {readiness['state']}")
    print(f"quote_next_step: {readiness['next_step']}")
    print(f"estimate_snapshot_id: {snapshot['estimate_snapshot_id']}")
    print(f"estimated_line_item_count: {len(snapshot.get('line_item_estimates') or [])}")
    print(f"quote_safe_line_item_count: {snapshot.get('quote_safe_line_item_count')}")
    if snapshot.get("blocking_reasons"):
        print("blocking_reasons:")
        for reason in snapshot["blocking_reasons"]:
            print(f"  - {reason}")
    print(f"packet_file: {packet_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
