#!/usr/bin/env python3
"""Governed quote_packet normalizer for messy inbound evidence."""

from __future__ import annotations

import argparse
import copy
import json
import os
import socket
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import parse as urlparse

import yaml

from customer_identity_common import introduction_name
from customer_mail_identity_common import first_name_token, projection_mode, salutation_text, validate_mail_identity_projection
from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root


CANONICAL_LINE_FIELDS = {
    "line_item_id",
    "product_type",
    "quantity",
    "size_breakdown",
    "description",
    "operator_notes",
    "decoration_method",
    "color_count",
    "print_locations",
    "blanks_cost_cents",
    "supplier_source",
    "lead_time_days",
    "method_variant",
    "underbase_needed",
    "stitch_count",
    "puff_mode",
    "thread_type",
    "hoop_class",
    "garment_material",
    "curved_panel_cap",
    "material_class",
    "transfer_type",
    "artwork_fingerprint_sha256",
    "garment_family",
    "graphic_size_inches",
    "size_tier_label",
    "setup_mode",
    "supplier_code",
    "supplier_sku",
    "style_code",
    "brand",
    "color",
    "canonical_style_key",
    "artwork_binding_ref",
    "source_confidence",
    "inventory_as_of_utc",
    "pricing_snapshot_id",
    "placement",
    "proof_required",
    "artie_supported",
    "requires_decoration_method",
    "artwork_required_for_pricing",
    "requires_shipping",
}

LINE_RUNTIME_HINT_FIELDS = {
    "proof_required",
    "artie_supported",
    "requires_decoration_method",
    "artwork_required_for_pricing",
    "requires_shipping",
}

PRICING_REQUIRED_FIELDS = (
    "line_item_id",
    "product_type",
    "quantity",
    "decoration_method",
    "color_count",
    "print_locations",
    "blanks_cost_cents",
    "supplier_source",
    "lead_time_days",
)
METHODS_REQUIRING_GRAPHIC_SIZE = {"screen_print", "engraving", "transfers"}
EMBROIDERY_GRAPHIC_SIZE_HOOPS = {"sleeve_hoop", "oversized_back_hoop"}
QUOTE_READY_TERMINAL_STATES = {"sent", "paid", "closed"}
QUOTE_REVIEW_READY_PACKET_STATES = {"ready_for_review", "approved_to_send"}


def has_canonical_value(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return value != ""
    if isinstance(value, (list, dict, tuple, set)):
        return bool(value)
    return True


def pricing_missing_fields(item: dict[str, Any]) -> list[str]:
    missing: list[str] = []
    for field in PRICING_REQUIRED_FIELDS:
        if not has_canonical_value(item.get(field)):
            missing.append(field)

    method = item.get("decoration_method")
    if not has_canonical_value(method):
        return missing

    if method == "screen_print":
        for field in ("method_variant", "underbase_needed", "graphic_size_inches", "size_tier_label", "setup_mode"):
            if not has_canonical_value(item.get(field)):
                missing.append(field)
    elif method == "embroidery":
        for field in ("stitch_count", "puff_mode", "thread_type", "hoop_class"):
            if not has_canonical_value(item.get(field)):
                missing.append(field)
        if item.get("puff_mode") == "puff" and not has_canonical_value(item.get("garment_material")):
            missing.append("garment_material")
        if item.get("hoop_class") == "cap_hoop" and item.get("curved_panel_cap") is not True:
            missing.append("curved_panel_cap")
        if item.get("hoop_class") in EMBROIDERY_GRAPHIC_SIZE_HOOPS and not has_canonical_value(item.get("graphic_size_inches")):
            missing.append("graphic_size_inches")
    elif method == "engraving":
        for field in ("graphic_size_inches", "size_tier_label", "setup_mode", "material_class"):
            if not has_canonical_value(item.get(field)):
                missing.append(field)
    elif method == "transfers":
        for field in (
            "graphic_size_inches",
            "size_tier_label",
            "setup_mode",
            "transfer_type",
            "artwork_fingerprint_sha256",
            "garment_family",
        ):
            if not has_canonical_value(item.get(field)):
                missing.append(field)

    if method in {"engraving", "transfers"} and item.get("setup_mode") == "re_setup":
        missing.append("prior_job_match")

    deduped: list[str] = []
    seen = set()
    for field in missing:
        if field in seen:
            continue
        seen.add(field)
        deduped.append(field)
    return deduped


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


def fail(message: str) -> None:
    print(f"FAIL (1): {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_json_arg(raw: str | None, label: str) -> Any:
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        fail(f"{label} must be valid JSON: {exc}")


def load_structured_file(path: Path) -> Any:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        return json.loads(text)
    return yaml.safe_load(text)


def tcp_port_open(host: str | None, port: int, timeout_seconds: int | float = 3) -> bool:
    if not host:
        return False
    try:
        with socket.create_connection((host, port), timeout=float(timeout_seconds)):
            return True
    except OSError:
        return False


def resolve_service_base_url_with_fallback(
    spine_root: Path,
    endpoint_id: str,
    fallback_url: str,
    timeout_seconds: int | float = 3,
) -> str:
    services_file = spine_root / "ops/bindings/services.health.yaml"
    ssh_file = spine_root / "ops/bindings/ssh.targets.yaml"
    if not services_file.exists():
        return fallback_url.rstrip("/")

    services = load_structured_file(services_file) or {}
    endpoints = services.get("endpoints") or []
    endpoint = next(
        (item for item in endpoints if isinstance(item, dict) and item.get("id") == endpoint_id),
        None,
    )
    if not endpoint:
        return fallback_url.rstrip("/")

    raw_url = str(endpoint.get("url") or "").strip()
    if not raw_url:
        return fallback_url.rstrip("/")

    parsed = urlparse.urlparse(raw_url)
    if not parsed.scheme or not parsed.netloc or not parsed.hostname:
        return fallback_url.rstrip("/")

    if not ssh_file.exists():
        return f"{parsed.scheme}://{parsed.netloc}"

    ssh_targets = load_structured_file(ssh_file) or {}
    targets = ((ssh_targets.get("ssh") or {}).get("targets") or [])
    target_id = str(endpoint.get("host") or "").strip()
    target = next(
        (item for item in targets if isinstance(item, dict) and item.get("id") == target_id),
        None,
    )
    if not target:
        return f"{parsed.scheme}://{parsed.netloc}"

    lan_host = str(target.get("host") or parsed.hostname or "").strip()
    tailscale_host = str(target.get("tailscale_ip") or "").strip()
    policy = str(target.get("access_policy") or "lan_first").strip() or "lan_first"
    port = parsed.port or (443 if parsed.scheme == "https" else 80)

    candidates: list[tuple[str, str]] = []
    if policy == "tailscale_required":
        if tailscale_host:
            candidates.append((tailscale_host, "tailscale"))
    elif policy == "lan_only":
        if lan_host:
            candidates.append((lan_host, "lan"))
    elif policy == "lan_first":
        if lan_host:
            candidates.append((lan_host, "lan"))
        if tailscale_host and tailscale_host != lan_host:
            candidates.append((tailscale_host, "tailscale"))
    else:
        if lan_host:
            candidates.append((lan_host, "direct"))

    resolved_host = parsed.hostname
    for candidate_host, _path in candidates:
        if tcp_port_open(candidate_host, port, timeout_seconds):
            resolved_host = candidate_host
            break

    resolved_netloc = parsed.netloc
    if parsed.hostname and resolved_host and resolved_host != parsed.hostname:
        resolved_netloc = parsed.netloc.replace(parsed.hostname, resolved_host, 1)

    return f"{parsed.scheme}://{resolved_netloc}".rstrip("/")


def deep_merge(base: Any, overlay: Any) -> Any:
    if isinstance(base, dict) and isinstance(overlay, dict):
        merged = dict(base)
        for key, value in overlay.items():
            if key in merged:
                merged[key] = deep_merge(merged[key], value)
            else:
                merged[key] = copy.deepcopy(value)
        return merged
    if isinstance(base, list) and isinstance(overlay, list):
        return copy.deepcopy(base) + copy.deepcopy(overlay)
    if overlay is None:
        return copy.deepcopy(base)
    return copy.deepcopy(overlay)


def source_key(ref: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(ref.get("ref_type") or ""),
        str(ref.get("source_locator") or ""),
        str(ref.get("seed_id") or ""),
        str(ref.get("summary") or ""),
    )


def line_key(item: dict[str, Any]) -> tuple[str, str]:
    return (
        str(item.get("line_item_id") or ""),
        line_signature(item),
    )


def line_signature(raw: dict[str, Any]) -> str:
    return "|".join(
        [
            str(raw.get("product_type") or ""),
            str(raw.get("description") or ""),
            json.dumps(raw.get("size_breakdown") or {}, sort_keys=True),
            str(raw.get("decoration_method") or ""),
            str(raw.get("placement") or ""),
            json.dumps(raw.get("print_locations") or [], sort_keys=True),
            str(raw.get("style_code") or ""),
            str(raw.get("supplier_sku") or ""),
            str(raw.get("color") or ""),
        ]
    )


def binding_key(binding: dict[str, Any]) -> tuple[str, str, str]:
    return (
        str(binding.get("line_item_id") or ""),
        json.dumps(binding.get("seed_refs") or [], sort_keys=True),
        json.dumps(binding.get("asset_refs") or [], sort_keys=True),
    )


def dedupe_list(values: list[dict[str, Any]], key_func) -> list[dict[str, Any]]:
    seen = set()
    result: list[dict[str, Any]] = []
    for value in values:
        key = key_func(value)
        if key in seen:
            continue
        seen.add(key)
        result.append(value)
    return result


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def extract_payload_from_packet(packet: dict[str, Any]) -> dict[str, Any]:
    payload: dict[str, Any] = {}
    for key in (
        "customer_ref",
        "source_refs",
        "line_items",
        "artwork_bindings",
        "inventory_snapshot",
        "estimate_snapshot",
        "pricing_snapshot",
        "quote_draft_ref",
        "customer_message_draft",
        "operator_notes",
    ):
        if key in packet:
            payload[key] = copy.deepcopy(packet[key])
    if packet.get("customer_ref", {}).get("customer_query"):
        payload["customer_query"] = packet["customer_ref"]["customer_query"]
    return payload


def normalize_source_refs(payload: dict[str, Any], timestamp: str, source_channel: str) -> list[dict[str, Any]]:
    refs: list[dict[str, Any]] = []

    for ref in payload.get("source_refs") or []:
        if not isinstance(ref, dict):
            continue
        normalized = {
            "intake_channel": ref.get("intake_channel") or source_channel,
            "source_timestamp": ref.get("source_timestamp") or timestamp,
        }
        for key in ("seed_id", "ref_type", "source_locator", "summary", "artifact_state"):
            if ref.get(key) not in (None, ""):
                normalized[key] = ref[key]
        refs.append(normalized)

    raw_summary = payload.get("raw_summary")
    if raw_summary:
        refs.append(
            {
                "intake_channel": source_channel,
                "source_timestamp": timestamp,
                "ref_type": "operator_note",
                "source_locator": "raw_summary",
                "summary": str(raw_summary),
                "artifact_state": "received",
            }
        )

    for link in payload.get("product_links") or []:
        if isinstance(link, str):
            refs.append(
                {
                    "intake_channel": source_channel,
                    "source_timestamp": timestamp,
                    "ref_type": "product_link",
                    "source_locator": link,
                    "summary": "product link supplied in inbound evidence",
                    "artifact_state": "received",
                }
            )
        elif isinstance(link, dict):
            refs.append(
                {
                    "intake_channel": link.get("intake_channel") or source_channel,
                    "source_timestamp": link.get("source_timestamp") or timestamp,
                    "ref_type": "product_link",
                    "source_locator": link.get("source_locator") or link.get("url") or "",
                    "summary": link.get("summary") or "product link supplied in inbound evidence",
                    "artifact_state": link.get("artifact_state") or "received",
                }
            )

    for ref in payload.get("historical_refs") or []:
        if not isinstance(ref, dict):
            continue
        refs.append(
            {
                "intake_channel": ref.get("intake_channel") or source_channel,
                "source_timestamp": ref.get("source_timestamp") or timestamp,
                "ref_type": ref.get("ref_type") or "historical_quote",
                "source_locator": ref.get("source_locator") or "",
                "summary": ref.get("summary") or "historical evidence reused for normalization",
                "artifact_state": ref.get("artifact_state") or "derived",
            }
        )

    seed_id = payload.get("seed_id")
    if seed_id:
        refs.append(
            {
                "seed_id": seed_id,
                "intake_channel": source_channel,
                "source_timestamp": timestamp,
                "ref_type": "seed",
                "source_locator": seed_id,
                "summary": "linked intake seed evidence",
                "artifact_state": "received",
            }
        )

    return dedupe_list(refs, source_key)


def normalize_line_items(payload: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    merged_items: dict[str, dict[str, Any]] = {}
    merged_hints: dict[str, dict[str, Any]] = {}
    ordered_keys: list[str] = []
    signature_to_key: dict[str, str] = {}
    for raw in payload.get("line_items") or []:
        if not isinstance(raw, dict):
            continue
        item = {}
        for key, value in raw.items():
            if key in CANONICAL_LINE_FIELDS and value not in (None, ""):
                item[key] = copy.deepcopy(value)
        if not item.get("product_type"):
            continue
        raw_line_id = str(item.get("line_item_id") or "").strip()
        signature = line_signature(raw)
        item_key = raw_line_id or signature
        if signature and signature in signature_to_key:
            item_key = signature_to_key[signature]
        elif raw_line_id and raw_line_id in merged_items:
            item_key = raw_line_id
        merged_item = deep_merge(merged_items.get(item_key, {}), item)
        merged_item["line_item_id"] = merged_item.get("line_item_id") or raw_line_id or str(uuid.uuid4())
        merged_items[item_key] = merged_item
        merged_hints[item_key] = deep_merge(
            merged_hints.get(item_key, {}),
            {key: raw.get(key) for key in LINE_RUNTIME_HINT_FIELDS if key in raw},
        )
        if signature:
            signature_to_key[signature] = item_key
        if item_key not in ordered_keys:
            ordered_keys.append(item_key)
    normalized = [merged_items[key] for key in ordered_keys]
    runtime_hints = [merged_hints.get(key, {}) for key in ordered_keys]
    return dedupe_list(normalized, line_key), runtime_hints


def build_artwork_bindings(
    payload: dict[str, Any], line_items: list[dict[str, Any]], timestamp: str
) -> tuple[list[dict[str, Any]], list[str], str]:
    bindings: list[dict[str, Any]] = []
    artwork_states: list[str] = []
    adequacy = "none"

    line_ids = [item["line_item_id"] for item in line_items]
    first_line_id = line_ids[0] if line_ids else None

    for raw in payload.get("artwork_bindings") or []:
        if not isinstance(raw, dict):
            continue
        binding = {
            "line_item_id": raw.get("line_item_id") or first_line_id,
            "seed_refs": raw.get("seed_refs") or [],
            "asset_refs": raw.get("asset_refs") or [],
            "artwork_job_refs": raw.get("artwork_job_refs") or [],
            "binding_state": raw.get("binding_state") or "unmapped",
        }
        if binding["line_item_id"]:
            bindings.append(binding)
        state = raw.get("artifact_state")
        if state:
            artwork_states.append(state)
        if raw.get("proof_adequate") is True and adequacy != "high":
            adequacy = "medium"

    for raw in payload.get("artwork_refs") or []:
        if not isinstance(raw, dict):
            continue
        artifact_state = raw.get("artifact_state") or "received"
        artwork_states.append(artifact_state)
        if raw.get("proof_adequate") is True:
            adequacy = "medium"
        if raw.get("vector_ready") is True:
            adequacy = "high"
        binding = {
            "line_item_id": raw.get("line_item_id") or first_line_id,
            "seed_refs": ([raw["seed_id"]] if raw.get("seed_id") else []),
            "asset_refs": ([raw["asset_ref"]] if raw.get("asset_ref") else raw.get("asset_refs") or []),
            "artwork_job_refs": ([raw["artwork_job_id"]] if raw.get("artwork_job_id") else []),
            "binding_state": raw.get("binding_state") or ("mapped" if raw.get("asset_ref") or raw.get("asset_refs") else "unmapped"),
        }
        if binding["line_item_id"]:
            bindings.append(binding)
        if raw.get("summary"):
            # keep provenance in source refs via caller payload
            pass

    bindings = [binding for binding in dedupe_list(bindings, binding_key) if binding.get("line_item_id")]

    if adequacy == "none" and any(state in {"received", "derived"} for state in artwork_states):
        adequacy = "low"

    return bindings, artwork_states, adequacy


def line_item_completeness(item: dict[str, Any]) -> str:
    if not item.get("product_type"):
        return "incomplete"
    if not pricing_missing_fields(item):
        return "pricing_ready"
    if item.get("quantity") and item.get("supplier_code") and item.get("supplier_sku"):
        return "stock_lookup_ready"
    return "creation_minimum"


def maybe_resolve_customer(
    payload: dict[str, Any], skip_customer_resolve: bool, spine_root: Path, mint_modules_root: Path
) -> tuple[dict[str, Any], str, str]:
    customer_ref = copy.deepcopy(payload.get("customer_ref") or payload.get("customer") or {})
    query = payload.get("customer_query") or customer_ref.get("customer_query") or customer_ref.get("customer_id") or ""
    notes = []
    resolution_state = "provided"

    if customer_ref.get("customer_id"):
        customer_ref["identity_state"] = "resolved"
        customer_ref.setdefault("customer_query", query or customer_ref["customer_id"])
        return customer_ref, "\n".join(notes), resolution_state

    if skip_customer_resolve or not query:
        customer_ref.setdefault("identity_state", "provisional")
        if query:
            customer_ref.setdefault("customer_query", query)
        return customer_ref, "\n".join(notes), "skipped"

    customer_resolve_script = mint_modules_root / "customers/scripts/customer-resolve.ts"
    infisical_agent = spine_root / "ops/plugins/providers/bin/infisical-agent.sh"

    if not customer_resolve_script.exists() or not infisical_agent.exists():
        customer_ref.setdefault("identity_state", "provisional")
        customer_ref.setdefault("customer_query", query)
        notes.append("customer resolution service unavailable during normalization")
        return customer_ref, "\n".join(notes), "service_unavailable"

    try:
        database_url = (
            subprocess.run(
                [str(infisical_agent), "secrets", "get", "--path", "/spine/services/customers", "--key", "CUSTOMERS_DATABASE_URL"],
                check=False,
                capture_output=True,
                text=True,
            ).stdout.strip()
        )
        if not database_url:
            customer_ref.setdefault("identity_state", "provisional")
            customer_ref.setdefault("customer_query", query)
            notes.append("CUSTOMERS_DATABASE_URL unavailable during normalization")
            return customer_ref, "\n".join(notes), "db_unavailable"

        result = subprocess.run(
            ["npm", "run", "--silent", "customer:resolve", "--", "--json", query],
            cwd=mint_modules_root / "customers",
            check=False,
            capture_output=True,
            text=True,
            env={**os.environ, "DATABASE_URL": database_url},
        )
        payload_json = json.loads(result.stdout or '{"state":"error"}')
    except Exception as exc:  # pragma: no cover - defensive
        customer_ref.setdefault("identity_state", "provisional")
        customer_ref.setdefault("customer_query", query)
        notes.append(f"customer resolution exception: {exc}")
        return customer_ref, "\n".join(notes), "error"

    state = payload_json.get("state") or "error"
    if state in {"exact_match", "normalized_match"}:
        resolved = payload_json.get("resolved_customer") or {}
        carried_contact_name = customer_ref.get("contact_name")
        carried_greeting_name = customer_ref.get("greeting_name")
        carried_salutation_mode = customer_ref.get("mail_salutation_mode")
        customer_ref = {
            "identity_state": "resolved",
            "customer_id": resolved.get("id"),
            "customer_query": query,
            "contact_name": carried_contact_name,
            "greeting_name": carried_greeting_name,
            "mail_salutation_mode": carried_salutation_mode,
        }
        if resolved.get("name"):
            customer_ref["resolved_name"] = resolved["name"]
        if resolved.get("email"):
            customer_ref["resolved_email"] = resolved["email"]
        if resolved.get("match_reason"):
            customer_ref["match_reason"] = resolved["match_reason"]
        return customer_ref, "\n".join(notes), state

    customer_ref.setdefault("identity_state", "provisional")
    customer_ref.setdefault("customer_query", query)
    if state == "ambiguous":
        notes.append("customer resolution returned multiple candidates")
    elif state == "new_customer":
        notes.append("customer resolution found no existing customer")
    else:
        notes.append(f"customer resolution returned {state}")
    return customer_ref, "\n".join(notes), state


def build_inventory_snapshot(
    payload: dict[str, Any], line_items: list[dict[str, Any]], skip_stock: bool, timestamp: str
) -> dict[str, Any] | None:
    existing = copy.deepcopy(payload.get("inventory_snapshot") or {})
    if existing:
        existing.setdefault("snapshot_timestamp", timestamp)
        existing.setdefault("supplier_results", [])
        existing.setdefault("stock_warnings", [])
        existing.setdefault("supplier_receipt_refs", [])
        existing.setdefault("stock_check_state", existing.get("stock_check_state") or "provided")
        return existing

    if skip_stock or not line_items:
        return None

    state = "not_requested"
    warnings: list[str] = []
    if any(item.get("quantity") and item.get("supplier_code") and item.get("supplier_sku") for item in line_items):
        state = "not_run"
        warnings.append("Stock check eligible but not executed by the normalizer runtime")
    elif any(item.get("product_type") for item in line_items):
        state = "blocked_supplier_unresolved"
        warnings.append("Stock lookup blocked until canonical supplier identifiers are known")

    return {
        "snapshot_timestamp": timestamp,
        "supplier_results": [],
        "stock_check_state": state,
        "stock_warnings": warnings,
        "supplier_receipt_refs": [],
    }


def build_pricing_snapshot(
    payload: dict[str, Any], line_items: list[dict[str, Any]], skip_pricing: bool, timestamp: str
) -> dict[str, Any] | None:
    existing = copy.deepcopy(payload.get("pricing_snapshot") or {})
    if existing:
        existing.setdefault("snapshot_timestamp", timestamp)
        existing.setdefault("pricing_snapshot_id", str(uuid.uuid4()))
        existing.setdefault("line_item_prices", [])
        existing.setdefault("decoration_prices", [])
        existing.setdefault("calculated_totals", {"subtotal": 0, "tax": 0, "shipping": 0, "total": 0})
        existing.setdefault("pricing_receipt_refs", [])
        existing.setdefault("confidence_level", "medium")
        existing.setdefault("pricing_state", existing.get("pricing_state") or "provided")
        return existing

    if skip_pricing or not line_items:
        return None

    any_pricing_ready = any(line_item_completeness(item) == "pricing_ready" for item in line_items)
    state = "not_requested" if any_pricing_ready else "blocked_insufficient_inputs"
    confidence = "low" if any_pricing_ready else "none"
    return {
        "snapshot_timestamp": timestamp,
        "pricing_snapshot_id": str(uuid.uuid4()),
        "pricing_state": state,
        "line_item_prices": [],
        "decoration_prices": [],
        "calculated_totals": {"subtotal": 0, "tax": 0, "shipping": 0, "total": 0},
        "pricing_receipt_refs": [],
        "confidence_level": confidence,
    }


def build_estimate_snapshot(payload: dict[str, Any], timestamp: str) -> dict[str, Any] | None:
    existing = copy.deepcopy(payload.get("estimate_snapshot") or {})
    if not existing:
        return None
    existing.setdefault("snapshot_timestamp", timestamp)
    existing.setdefault("estimate_snapshot_id", str(uuid.uuid4()))
    existing.setdefault("estimate_state", existing.get("estimate_state") or "provided")
    existing.setdefault("line_item_estimates", [])
    existing.setdefault("calculated_totals", {"subtotal": 0, "tax": 0, "shipping": 0, "total": 0})
    existing.setdefault("estimate_receipt_refs", [])
    existing.setdefault("confidence_level", "medium")
    existing.setdefault("blocking_reasons", [])
    existing.setdefault("quote_safe_line_item_count", len([row for row in existing.get("line_item_estimates") or [] if row.get("quote_safe_now")]))
    existing.setdefault(
        "clarification_needed_count",
        len([row for row in existing.get("line_item_estimates") or [] if row.get("estimate_status") == "clarification_needed"]),
    )
    existing.setdefault("estimate_authority_path", "mint.quote.packet.estimate")
    return existing


def add_gap(
    gaps: list[dict[str, Any]],
    gap_type: str,
    description: str,
    severity: str,
    resolution_path: str,
    timestamp: str,
) -> None:
    for gap in gaps:
        if gap["gap_type"] == gap_type and gap["description"] == description:
            return
    gaps.append(
        {
            "gap_id": 0,
            "gap_type": gap_type,
            "description": description,
            "severity": severity,
            "discovered_at": timestamp,
            "resolution_path": resolution_path,
        }
    )


def derive_gaps_and_decisions(
    payload: dict[str, Any],
    customer_ref: dict[str, Any],
    line_items: list[dict[str, Any]],
    line_hints: list[dict[str, Any]],
    artwork_states: list[str],
    artwork_adequacy: str,
    timestamp: str,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    gaps: list[dict[str, Any]] = []
    decisions = {
        "clarification_required": False,
        "artie_route_allowed": False,
        "artie_route_reason": "not_required",
        "pricing_ready_allowed": False,
        "ready_for_review_allowed": False,
    }

    if customer_ref.get("identity_state") != "resolved":
        add_gap(
            gaps,
            "customer_unresolved",
            "Customer identity is not yet resolved to a governed customer_id",
            "blocking",
            "Resolve the customer or provide a resolved customer_ref",
            timestamp,
        )

    if not line_items:
        add_gap(
            gaps,
            "product_unresolved",
            "No normalized product family could be created from the inbound evidence",
            "blocking",
            "Provide product family details or add evidence-backed line_items",
            timestamp,
        )

    clarification = payload.get("clarification") or {}
    if clarification.get("required"):
        clarification_severity = str(clarification.get("severity") or "").strip().lower()
        if clarification_severity not in {"blocking", "warning"}:
            clarification_severity = "blocking" if clarification.get("blocking", True) else "warning"
        decisions["clarification_required"] = True
        add_gap(
            gaps,
            "clarification_required",
            clarification.get("summary") or "Written clarification is required before quote readiness",
            clarification_severity,
            "Send the generated clarification draft and wait for written confirmation",
            timestamp,
        )

    relationship = payload.get("relationship_pricing") or {}
    if relationship.get("status") in {"review_required", "historical_match_review", "courtesy_review"}:
        add_gap(
            gaps,
            "pricing_policy_review",
            relationship.get("summary") or "Relationship pricing or courtesy adjustment requires operator review",
            "blocking" if relationship.get("blocks_review", True) else "warning",
            "Resolve discretionary pricing before marking the packet ready for review",
            timestamp,
        )

    shipping = payload.get("shipping") or {}
    if shipping.get("status") in {"ambiguous", "pending", "unknown"}:
        add_gap(
            gaps,
            "shipping_ambiguity",
            shipping.get("summary") or "Shipping truth is not yet explicit",
            "blocking" if shipping.get("blocks_review", True) else "warning",
            "Clarify ship method or exclude shipping honestly from the current quote total",
            timestamp,
        )

    product_ambiguous = bool(payload.get("product_ambiguous"))
    if product_ambiguous:
        add_gap(
            gaps,
            "product_unresolved",
            payload.get("product_ambiguity_summary") or "Product family or grouping remains ambiguous",
            "blocking",
            "Clarify the exact products before proceeding",
            timestamp,
        )
        decisions["clarification_required"] = True

    for item, hints in zip(line_items, line_hints):
        if not item.get("quantity"):
            add_gap(
                gaps,
                "quantity_unresolved",
                f"Quantity missing for {item.get('description') or item['product_type']}",
                "blocking",
                "Obtain exact quantities before pricing or review",
                timestamp,
            )

        requires_decoration = hints.get("requires_decoration_method", True)
        if requires_decoration and not item.get("decoration_method"):
            add_gap(
                gaps,
                "decoration_unresolved",
                f"Decoration method missing for {item.get('description') or item['product_type']}",
                "blocking",
                "Confirm decoration method, print locations, and color count",
                timestamp,
            )

        if not item.get("supplier_code") and item.get("quantity") and not item.get("blanks_cost_cents"):
            add_gap(
                gaps,
                "supplier_unresolved",
                f"Blank source unresolved for {item.get('description') or item['product_type']}",
                "blocking",
                "Choose a canonical supplier path or record trustworthy historical blank pricing evidence",
                timestamp,
            )

    if any(state in {"missing", "failed"} for state in artwork_states):
        add_gap(
            gaps,
            "artwork_missing" if all(state == "missing" for state in artwork_states) else "artwork_inadequate",
            payload.get("artwork_summary") or "Artwork is missing or upload failed",
            "blocking",
            "Request usable artwork before proofing or art-dependent pricing",
            timestamp,
        )
        decisions["clarification_required"] = True
    elif any(state == "low_quality" for state in artwork_states) or artwork_adequacy == "low":
        add_gap(
            gaps,
            "artwork_inadequate",
            payload.get("artwork_summary") or "Artwork is present but not proof-adequate",
            "blocking",
            "Request higher-quality or vector artwork",
            timestamp,
        )
        decisions["clarification_required"] = True

    proof_required = bool((payload.get("routing") or {}).get("proof_required")) or any(
        bool(hints.get("proof_required")) for hints in line_hints
    )
    artie_supported = all(hints.get("artie_supported", True) for hints in line_hints) if line_hints else True
    no_art_block = not any(gap["gap_type"] in {"artwork_missing", "artwork_inadequate"} for gap in gaps)
    no_product_block = not any(gap["gap_type"] in {"product_unresolved", "decoration_unresolved", "clarification_required"} for gap in gaps)
    if proof_required:
        if artwork_adequacy in {"medium", "high"} and artie_supported and no_art_block and no_product_block:
            decisions["artie_route_allowed"] = True
            decisions["artie_route_reason"] = "allowed"
        else:
            decisions["artie_route_reason"] = "blocked"
            add_gap(
                gaps,
                "proof_routing_blocked",
                "Proof work cannot route to Artie until artwork and product truth are adequate",
                "blocking",
                "Resolve the underlying artwork/product clarification gaps first",
                timestamp,
            )

    # Canonical gap ids must be sequential per packet.
    for idx, gap in enumerate(gaps, start=1):
        gap["gap_id"] = idx

    return gaps, decisions


def customer_confidence(customer_ref: dict[str, Any], resolution_state: str) -> str:
    if customer_ref.get("identity_state") == "resolved" and customer_ref.get("customer_id"):
        return "high"
    if resolution_state in {"ambiguous", "new_customer"}:
        return "low"
    if customer_ref.get("customer_query"):
        return "medium"
    return "none"


def artwork_confidence(artwork_adequacy: str, artwork_states: list[str]) -> str:
    if artwork_adequacy == "high":
        return "high"
    if artwork_adequacy == "medium":
        return "medium"
    if artwork_adequacy == "low" or any(state == "low_quality" for state in artwork_states):
        return "low"
    if any(state in {"received", "derived"} for state in artwork_states):
        return "low"
    return "none"


def stock_confidence(inventory_snapshot: dict[str, Any] | None, line_items: list[dict[str, Any]]) -> str:
    if inventory_snapshot and inventory_snapshot.get("stock_check_state") == "completed":
        return "high"
    if any(item.get("supplier_code") and item.get("supplier_sku") for item in line_items):
        return "medium"
    if any(item.get("product_type") for item in line_items):
        return "low"
    return "none"


def pricing_confidence(pricing_snapshot: dict[str, Any] | None, gaps: list[dict[str, Any]]) -> str:
    if pricing_snapshot and pricing_snapshot.get("pricing_state") in {"completed", "provided"}:
        return str(pricing_snapshot.get("confidence_level") or "medium")
    if any(gap["gap_type"] in {"quantity_unresolved", "decoration_unresolved", "supplier_unresolved", "pricing_policy_review"} and gap["severity"] == "blocking" for gap in gaps):
        return "none"
    if pricing_snapshot:
        return str(pricing_snapshot.get("confidence_level") or "low")
    return "none"


def overall_confidence(customer: str, artwork: str, stock: str, pricing: str, gaps: list[dict[str, Any]]) -> str:
    if any(gap["severity"] == "blocking" for gap in gaps):
        return "low"
    if all(level == "high" for level in (customer, pricing)) and stock in {"high", "medium"} and artwork in {"high", "medium", "none"}:
        return "high"
    return "medium"


def packet_blocking_gaps(packet: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        gap
        for gap in (packet.get("open_gaps") or [])
        if isinstance(gap, dict) and str(gap.get("severity") or "") == "blocking"
    ]


def quote_line_item_count(packet: dict[str, Any]) -> int:
    return len([item for item in (packet.get("line_items") or []) if isinstance(item, dict)])


def estimate_state(packet: dict[str, Any]) -> str:
    return str(((packet.get("estimate_snapshot") or {}).get("estimate_state")) or "")


def pricing_state(packet: dict[str, Any]) -> str:
    return str(((packet.get("pricing_snapshot") or {}).get("pricing_state")) or "")


def pricing_completed(packet: dict[str, Any]) -> bool:
    snapshot = packet.get("pricing_snapshot") or {}
    if not isinstance(snapshot, dict):
        return False
    if str(snapshot.get("pricing_state") or "") not in {"completed", "provided"}:
        return False
    return str(snapshot.get("confidence_level") or "none") in {"medium", "high"}


def estimate_covers_all_line_items(packet: dict[str, Any]) -> bool:
    snapshot = packet.get("estimate_snapshot") or {}
    if not isinstance(snapshot, dict):
        return False
    if str(snapshot.get("estimate_state") or "") not in {"completed", "partial", "provided"}:
        return False
    total = quote_line_item_count(packet)
    if total <= 0:
        return False
    quote_safe_count = int(snapshot.get("quote_safe_line_item_count") or 0)
    return quote_safe_count >= total


def build_basis(packet: dict[str, Any]) -> str:
    if pricing_completed(packet):
        return "exact_pricing_ready"
    if estimate_covers_all_line_items(packet):
        return "estimate_safe"
    return "not_ready"


def completed_internal_work(packet: dict[str, Any]) -> bool:
    inventory_snapshot = packet.get("inventory_snapshot") or {}
    if isinstance(inventory_snapshot, dict) and str(inventory_snapshot.get("stock_check_state") or "") in {
        "completed",
        "partial",
        "sourced_without_stock",
    }:
        return True
    estimate_snapshot = packet.get("estimate_snapshot") or {}
    if isinstance(estimate_snapshot, dict) and (
        int(estimate_snapshot.get("quote_safe_line_item_count") or 0) > 0
        or str(estimate_snapshot.get("estimate_state") or "") in {"completed", "partial", "provided"}
    ):
        return True
    pricing_snapshot = packet.get("pricing_snapshot") or {}
    if isinstance(pricing_snapshot, dict) and (
        str(pricing_snapshot.get("pricing_state") or "") in {"completed", "provided"}
        or bool(pricing_snapshot.get("line_item_prices"))
    ):
        return True
    return bool(packet.get("quote_draft_ref") or packet.get("customer_message_draft"))


def grouped_blocking_gaps(packet: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for gap in packet_blocking_gaps(packet):
        gap_type = str(gap.get("gap_type") or "")
        grouped.setdefault(gap_type, []).append(gap)
    return grouped


def gap_summary(grouped: dict[str, list[dict[str, Any]]], gap_type: str, fallback: str) -> str:
    entries = grouped.get(gap_type) or []
    if not entries:
        return fallback
    description = str(entries[0].get("description") or "").strip()
    if description:
        return description
    return fallback


def append_readiness_missing(
    missing: list[dict[str, str]],
    code: str,
    summary: str,
    source: str,
) -> None:
    if any(str(entry.get("code") or "") == code for entry in missing):
        return
    missing.append(
        {
            "code": code,
            "summary": summary,
            "source": source,
        }
    )


def build_missing_requirements(packet: dict[str, Any]) -> list[dict[str, str]]:
    missing: list[dict[str, str]] = []
    grouped = grouped_blocking_gaps(packet)
    basis = build_basis(packet)

    if quote_line_item_count(packet) == 0:
        append_readiness_missing(
            missing,
            "line_items",
            "No governed line items exist yet for this quote packet.",
            "intake",
        )

    if grouped.get("clarification_required"):
        append_readiness_missing(
            missing,
            "clarification",
            gap_summary(grouped, "clarification_required", "Customer clarification is still required before quoting cleanly."),
            "customer",
        )
    if grouped.get("product_unresolved"):
        append_readiness_missing(
            missing,
            "product_scope",
            gap_summary(grouped, "product_unresolved", "The exact product or grouping is still unresolved."),
            "customer",
        )
    if grouped.get("quantity_unresolved"):
        append_readiness_missing(
            missing,
            "quantity",
            gap_summary(grouped, "quantity_unresolved", "Exact quantities are still missing."),
            "customer",
        )
    if grouped.get("decoration_unresolved") and basis == "not_ready":
        append_readiness_missing(
            missing,
            "decoration_scope",
            gap_summary(grouped, "decoration_unresolved", "Decoration method, locations, or pricing inputs are still unresolved."),
            "customer",
        )
    if grouped.get("supplier_unresolved") and basis == "not_ready":
        append_readiness_missing(
            missing,
            "blank_source",
            gap_summary(grouped, "supplier_unresolved", "Blank sourcing truth is still unresolved."),
            "supplier",
        )
    if (grouped.get("artwork_missing") or grouped.get("artwork_inadequate")) and basis == "not_ready":
        gap_type = "artwork_missing" if grouped.get("artwork_missing") else "artwork_inadequate"
        append_readiness_missing(
            missing,
            "artwork_scope",
            gap_summary(grouped, gap_type, "Artwork evidence is still too weak to quote safely."),
            "artwork",
        )

    return missing


def send_missing_requirements(packet: dict[str, Any], build_missing: list[dict[str, str]]) -> list[dict[str, str]]:
    packet_state = str(packet.get("state") or "")
    if packet_state in QUOTE_READY_TERMINAL_STATES:
        return []

    missing = copy.deepcopy(build_missing)
    customer_ref = packet.get("customer_ref") or {}
    grouped = grouped_blocking_gaps(packet)
    if str(customer_ref.get("identity_state") or "") != "resolved":
        append_readiness_missing(
            missing,
            "customer_identity",
            "Customer identity is not resolved to a governed customer record yet.",
            "customer",
        )
    if grouped.get("shipping_ambiguity"):
        append_readiness_missing(
            missing,
            "shipping_scope",
            gap_summary(grouped, "shipping_ambiguity", "Shipping posture is still ambiguous."),
            "customer",
        )
    if grouped.get("pricing_policy_review"):
        append_readiness_missing(
            missing,
            "pricing_review",
            gap_summary(grouped, "pricing_policy_review", "Pricing policy review is still required before send."),
            "operator",
        )

    if not pricing_completed(packet):
        snapshot = packet.get("pricing_snapshot") or {}
        summary = "Exact pricing snapshot is not complete yet."
        if isinstance(snapshot, dict):
            current_state = str(snapshot.get("pricing_state") or "").strip()
            if current_state:
                summary = f"Exact pricing snapshot is not complete yet ({current_state})."
            blocking_reasons = snapshot.get("blocking_reasons") or []
            if isinstance(blocking_reasons, list) and blocking_reasons:
                summary = str(blocking_reasons[0])
        append_readiness_missing(
            missing,
            "exact_pricing",
            summary,
            "pricing",
        )

    if not packet.get("quote_draft_ref"):
        append_readiness_missing(
            missing,
            "quote_draft",
            "A governed quote draft has not been rendered yet.",
            "quote_packet",
        )
    if not str(packet.get("customer_message_draft") or "").strip():
        append_readiness_missing(
            missing,
            "customer_message",
            "A governed customer-facing message draft has not been rendered yet.",
            "quote_packet",
        )

    non_approval_missing = [entry for entry in missing if str(entry.get("code") or "") != "operator_approval"]
    review_ready = not non_approval_missing
    if review_ready and packet_state != "approved_to_send":
        append_readiness_missing(
            missing,
            "operator_approval",
            "Operator review and approval are still required before send.",
            "operator",
        )

    return missing


def quote_readiness_state(
    packet: dict[str, Any],
    build_missing: list[dict[str, str]],
    send_missing: list[dict[str, str]],
) -> str:
    packet_state = str(packet.get("state") or "")
    if packet_state in QUOTE_READY_TERMINAL_STATES:
        return "quote_sent"
    if not build_missing and not completed_internal_work(packet):
        return "ready_for_quote_build"
    review_blockers = [entry for entry in send_missing if str(entry.get("code") or "") != "operator_approval"]
    if packet_state == "approved_to_send" and not send_missing:
        return "ready_for_operator_send"
    if packet_state in QUOTE_REVIEW_READY_PACKET_STATES and not review_blockers:
        return "ready_for_operator_review"
    if build_missing:
        return "needs_customer_input"
    return "quote_packet_in_progress"


def quote_readiness_next_step(
    packet: dict[str, Any],
    build_missing: list[dict[str, str]],
    send_missing: list[dict[str, str]],
) -> str:
    packet_state = str(packet.get("state") or "")
    if packet_state == "paid":
        return "handoff_to_production"
    if packet_state in {"sent", "closed"}:
        return "await_customer_response"

    if build_missing:
        code = str(build_missing[0].get("code") or "")
        if code == "blank_source":
            return "run_quote_source"
        if code == "artwork_scope":
            return "clarify_artwork_scope"
        if code == "line_items":
            return "normalize_line_items"
        return "ask_customer_blocker"

    if not pricing_completed(packet):
        if build_basis(packet) == "estimate_safe":
            return "run_quote_price"
        inventory_snapshot = packet.get("inventory_snapshot") or {}
        if isinstance(inventory_snapshot, dict) and str(inventory_snapshot.get("stock_check_state") or "") in {
            "",
            "not_requested",
            "not_run",
            "blocked_supplier_unresolved",
            "api_key_unavailable",
        }:
            return "run_quote_source"
        if not estimate_covers_all_line_items(packet):
            return "run_quote_estimate"
        return "run_quote_price"

    if not packet.get("quote_draft_ref") or not str(packet.get("customer_message_draft") or "").strip():
        return "render_quote_review"

    review_blockers = [entry for entry in send_missing if str(entry.get("code") or "") != "operator_approval"]
    if packet_state == "approved_to_send" and not send_missing:
        return "send_quote"
    if not review_blockers:
        return "operator_review"
    return "resolve_quote_send_blocker"


def compute_quote_readiness(packet: dict[str, Any]) -> dict[str, Any]:
    build_missing = build_missing_requirements(packet)
    send_missing = send_missing_requirements(packet, build_missing)
    review_ready = not [entry for entry in send_missing if str(entry.get("code") or "") != "operator_approval"]
    send_ready = str(packet.get("state") or "") == "approved_to_send" and not send_missing
    readiness_state = quote_readiness_state(packet, build_missing, send_missing)

    return {
        "state": readiness_state,
        "packet_state": str(packet.get("state") or ""),
        "build_basis": build_basis(packet),
        "build_ready": not build_missing,
        "review_ready": review_ready,
        "send_ready": send_ready,
        "estimate_state": estimate_state(packet) or "not_requested",
        "pricing_state": pricing_state(packet) or "not_requested",
        "missing_for_build": build_missing,
        "missing_for_send": send_missing,
        "next_step": quote_readiness_next_step(packet, build_missing, send_missing),
    }


def sync_quote_readiness(packet: dict[str, Any]) -> dict[str, Any]:
    packet["quote_readiness"] = compute_quote_readiness(packet)
    return packet["quote_readiness"]


def build_customer_message_draft(
    payload: dict[str, Any], customer_ref: dict[str, Any], gaps: list[dict[str, Any]]
) -> str:
    if payload.get("customer_message_draft"):
        return str(payload["customer_message_draft"])

    clarification = payload.get("clarification") or {}
    questions = [str(question) for question in clarification.get("questions") or [] if question]
    if not questions:
        for gap in gaps:
            if gap["severity"] != "blocking":
                continue
            if gap["gap_type"] == "quantity_unresolved":
                questions.append("the exact quantity you want quoted")
            elif gap["gap_type"] == "decoration_unresolved":
                questions.append("the decoration method and print locations")
            elif gap["gap_type"] in {"artwork_missing", "artwork_inadequate"}:
                questions.append("usable artwork files")
            elif gap["gap_type"] == "supplier_unresolved":
                questions.append("the blank/style or product source to quote")
            elif gap["gap_type"] == "shipping_ambiguity":
                questions.append("your shipping preference or in-hands deadline")
            elif gap["gap_type"] == "clarification_required":
                questions.append(gap["description"])
            elif gap["gap_type"] == "product_unresolved":
                questions.append("the exact product or grouping you want quoted")

    if not questions:
        return ""

    salutation = salutation_text(
        {
            "greeting_name": customer_ref.get("greeting_name"),
            "mail_salutation_mode": customer_ref.get("mail_salutation_mode"),
        },
        named_prefix="Hi",
    )
    deduped_questions = []
    seen = set()
    for question in questions:
        if question in seen:
            continue
        seen.add(question)
        deduped_questions.append(question)

    bullets = "\n".join(f"- {question}" for question in deduped_questions)
    return (
        f"{salutation}\n\n"
        "I can keep moving on your quote, but I still need a few details in writing:\n"
        f"{bullets}\n\n"
        "Once I have that, I can update the packet and keep the quote moving.\n\n"
        "Thanks,\nRonny"
    )


def contact_name_from_source_evidence(payload: dict[str, Any], source_refs: list[dict[str, Any]]) -> str:
    customer_ref = payload.get("customer_ref") or {}
    explicit = str(customer_ref.get("contact_name") or "").strip()
    if explicit:
        return explicit

    evidence_texts: list[str] = []
    for ref in source_refs:
        if not isinstance(ref, dict):
            continue
        summary = str(ref.get("summary") or "").strip()
        if summary:
            evidence_texts.append(summary)
    draft_text = str(payload.get("customer_message_draft") or "").strip()
    if draft_text:
        evidence_texts.append(draft_text)

    for text in evidence_texts:
        candidate = introduction_name(text, line_limit=0, allow_embedded=True)
        if candidate:
            return candidate
    return ""


def greeting_name_from_source_evidence(payload: dict[str, Any], source_refs: list[dict[str, Any]], contact_name: str = "") -> str:
    customer_ref = payload.get("customer_ref") or {}
    explicit = str(customer_ref.get("greeting_name") or "").strip()
    if explicit:
        return explicit
    return first_name_token(contact_name)


def build_packet(
    packet_id: str,
    payload: dict[str, Any],
    timestamp: str,
    created_at: str,
    created_by: str,
    receipts: list[dict[str, Any]],
    skip_stock: bool,
    skip_pricing: bool,
    skip_customer_resolve: bool,
    spine_root: Path,
    mint_modules_root: Path,
) -> tuple[dict[str, Any], dict[str, Any]]:
    source_channel = str(payload.get("source_channel") or "manual")
    customer_ref, customer_resolution_note, resolution_state = maybe_resolve_customer(
        payload, skip_customer_resolve, spine_root, mint_modules_root
    )
    source_refs = normalize_source_refs(payload, timestamp, source_channel)
    contact_name = contact_name_from_source_evidence(payload, source_refs)
    greeting_name = greeting_name_from_source_evidence(payload, source_refs, contact_name)
    if contact_name and not str(customer_ref.get("contact_name") or "").strip():
        customer_ref["contact_name"] = contact_name
    if greeting_name and not str(customer_ref.get("greeting_name") or "").strip():
        customer_ref["greeting_name"] = greeting_name
    customer_ref["mail_salutation_mode"] = projection_mode(
        str(customer_ref.get("contact_name") or ""),
        str(customer_ref.get("greeting_name") or ""),
        str(customer_ref.get("mail_salutation_mode") or ""),
    )
    identity_validation = validate_mail_identity_projection(
        {
            "resolved_name": customer_ref.get("resolved_name"),
            "resolved_email": customer_ref.get("resolved_email"),
            "contact_name": customer_ref.get("contact_name"),
            "greeting_name": customer_ref.get("greeting_name"),
            "mail_salutation_mode": customer_ref.get("mail_salutation_mode"),
        }
    )
    if identity_validation:
        customer_ref["mail_identity_validation"] = identity_validation
    line_items, line_hints = normalize_line_items(payload)
    artwork_bindings, artwork_states, artwork_adequacy = build_artwork_bindings(payload, line_items, timestamp)
    inventory_snapshot = build_inventory_snapshot(payload, line_items, skip_stock, timestamp)
    estimate_snapshot = build_estimate_snapshot(payload, timestamp)
    pricing_snapshot = build_pricing_snapshot(payload, line_items, skip_pricing, timestamp)
    gaps, decisions = derive_gaps_and_decisions(
        payload,
        customer_ref,
        line_items,
        line_hints,
        artwork_states,
        artwork_adequacy,
        timestamp,
    )

    if customer_resolution_note:
        operator_notes = "\n".join(
            part
            for part in [payload.get("operator_notes", ""), customer_resolution_note]
            if part
        )
    else:
        operator_notes = str(payload.get("operator_notes") or "")

    customer_message_draft = build_customer_message_draft(payload, customer_ref, gaps)

    customer_conf = customer_confidence(customer_ref, resolution_state)
    art_conf = artwork_confidence(artwork_adequacy, artwork_states)
    stock_conf = stock_confidence(inventory_snapshot, line_items)
    price_conf = pricing_confidence(pricing_snapshot, gaps)
    overall_conf = overall_confidence(customer_conf, art_conf, stock_conf, price_conf, gaps)

    confidence = {
        "overall": overall_conf,
        "artwork_confidence": art_conf,
        "estimate_confidence": str((estimate_snapshot or {}).get("confidence_level") or "none"),
        "pricing_confidence": price_conf,
        "stock_confidence": stock_conf,
        "customer_confidence": customer_conf,
    }

    blocking_gaps = [gap for gap in gaps if gap["severity"] == "blocking"]
    ready_for_review_allowed = (
        customer_ref.get("identity_state") == "resolved"
        and not blocking_gaps
        and pricing_snapshot
        and pricing_snapshot.get("confidence_level") in {"medium", "high"}
        and payload.get("quote_draft_ref")
        and bool(customer_message_draft)
        and (
            not decisions["artie_route_allowed"]
            or not any(gap["gap_type"] == "proof_routing_blocked" for gap in gaps)
        )
    )
    decisions["pricing_ready_allowed"] = all(
        line_item_completeness(item) == "pricing_ready" for item in line_items
    ) and not any(
        gap["gap_type"] in {"quantity_unresolved", "decoration_unresolved", "supplier_unresolved", "pricing_policy_review"}
        and gap["severity"] == "blocking"
        for gap in gaps
    )
    decisions["ready_for_review_allowed"] = bool(ready_for_review_allowed)

    state = "needs_input" if blocking_gaps else "drafting"
    if ready_for_review_allowed:
        state = "ready_for_review"

    packet: dict[str, Any] = {
        "quote_packet_id": packet_id,
        "state": state,
        "customer_ref": customer_ref,
        "source_refs": source_refs,
        "line_items": line_items,
        "created_at": created_at,
        "updated_at": timestamp,
        "created_by": created_by,
        "open_gaps": gaps,
        "confidence": confidence,
        "receipts": receipts,
    }

    if artwork_bindings:
        packet["artwork_bindings"] = artwork_bindings
    if inventory_snapshot:
        packet["inventory_snapshot"] = inventory_snapshot
    if estimate_snapshot:
        packet["estimate_snapshot"] = estimate_snapshot
    if pricing_snapshot:
        packet["pricing_snapshot"] = pricing_snapshot
    if isinstance(payload.get("artwork_analysis"), dict) and payload.get("artwork_analysis"):
        packet["artwork_analysis"] = copy.deepcopy(payload["artwork_analysis"])
    if payload.get("quote_draft_ref"):
        packet["quote_draft_ref"] = copy.deepcopy(payload["quote_draft_ref"])
    if customer_message_draft:
        packet["customer_message_draft"] = customer_message_draft
    if operator_notes:
        packet["operator_notes"] = operator_notes
    sync_quote_readiness(packet)

    return packet, decisions


def update_index(index_file: Path, packet: dict[str, Any], timestamp: str) -> None:
    if index_file.exists():
        index_data = yaml.safe_load(index_file.read_text(encoding="utf-8")) or {}
    else:
        index_data = {"packets": []}

    packets = index_data.setdefault("packets", [])
    customer_query = (
        packet.get("customer_ref", {}).get("customer_query")
        or packet.get("customer_ref", {}).get("customer_id")
        or "unknown"
    )
    existing = next((entry for entry in packets if entry.get("quote_packet_id") == packet["quote_packet_id"]), None)
    if existing:
        existing["state"] = packet["state"]
        existing["customer_query"] = customer_query
        existing["updated_at"] = timestamp
    else:
        packets.append(
            {
                "quote_packet_id": packet["quote_packet_id"],
                "state": packet["state"],
                "customer_query": customer_query,
                "created_at": packet["created_at"],
                "updated_at": timestamp,
            }
        )

    ensure_dir(index_file.parent)
    index_file.write_text(yaml.safe_dump(index_data, sort_keys=False), encoding="utf-8")


def append_receipt(existing_receipts: list[dict[str, Any]], capability_name: str, timestamp: str) -> list[dict[str, Any]]:
    receipts = copy.deepcopy(existing_receipts)
    run_key = os.environ.get("SPINE_CAP_RUN_KEY")
    if not run_key:
        return receipts
    receipts.append(
        {
            "receipt_path": f"evidence/sessions/R{run_key}/receipt.md",
            "capability_name": capability_name,
            "run_key": run_key,
            "executed_at": timestamp,
        }
    )
    return receipts


def dump_yaml(path: Path, payload: dict[str, Any]) -> None:
    ensure_dir(path.parent)
    path.write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-prepare",
        description="Normalize messy inbound evidence into a governed quote_packet work object.",
    )
    parser.add_argument("--customer", help="Legacy customer query input")
    parser.add_argument("--packet-id", help="Update an existing packet by id")
    parser.add_argument("--seed-id", help="Link intake seed evidence")
    parser.add_argument("--line-items", help="Legacy JSON array of line items")
    parser.add_argument("--source-channel", help="Source channel for the inbound evidence")
    parser.add_argument("--raw-summary", help="Raw inbound summary")
    parser.add_argument("--product-links", help="JSON array of product links or link objects")
    parser.add_argument("--artwork-refs", help="JSON array of artwork refs")
    parser.add_argument("--historical-refs", help="JSON array of historical refs")
    parser.add_argument("--operator-notes", help="Operator notes to preserve in the packet")
    parser.add_argument("--evidence-json", help="Structured evidence payload as JSON")
    parser.add_argument("--evidence-file", help="Structured evidence payload file (json|yaml)")
    parser.add_argument("--skip-stock-check", action="store_true", help="Do not populate inventory snapshot heuristics")
    parser.add_argument("--skip-pricing", action="store_true", help="Do not populate pricing snapshot heuristics")
    parser.add_argument("--skip-customer-resolve", action="store_true", help="Do not call the external customer resolution path")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.packet.normalize"


def build_payload_from_args(args: argparse.Namespace, existing_packet: dict[str, Any] | None) -> dict[str, Any]:
    payload: dict[str, Any] = extract_payload_from_packet(existing_packet or {})

    if args.evidence_file:
        payload = deep_merge(payload, load_structured_file(Path(args.evidence_file)) or {})
    if args.evidence_json:
        payload = deep_merge(payload, parse_json_arg(args.evidence_json, "--evidence-json") or {})

    legacy: dict[str, Any] = {}
    if args.customer:
        legacy["customer_query"] = args.customer
    if args.seed_id:
        legacy["seed_id"] = args.seed_id
    if args.line_items:
        legacy["line_items"] = parse_json_arg(args.line_items, "--line-items") or []
    if args.source_channel:
        legacy["source_channel"] = args.source_channel
    if args.raw_summary:
        legacy["raw_summary"] = args.raw_summary
    if args.product_links:
        legacy["product_links"] = parse_json_arg(args.product_links, "--product-links") or []
    if args.artwork_refs:
        legacy["artwork_refs"] = parse_json_arg(args.artwork_refs, "--artwork-refs") or []
    if args.historical_refs:
        legacy["historical_refs"] = parse_json_arg(args.historical_refs, "--historical-refs") or []
    if args.operator_notes:
        legacy["operator_notes"] = args.operator_notes

    return deep_merge(payload, legacy)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    spine_root = resolve_spine_root(__file__)
    mint_root = resolve_mint_data_root(spine_root=spine_root, current_file=__file__)
    mint_modules_root = Path(os.environ.get("MINT_MODULES_ROOT") or "/Users/ronnyworks/code/mint-modules")
    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (mint_root / "quote-packets"))
    index_file = Path(os.environ.get("MINT_QUOTE_PACKET_INDEX_FILE") or (mint_root / "quote-packets-index.yaml"))

    ensure_dir(packets_dir)

    packet_id = args.packet_id or str(uuid.uuid4())
    packet_file = packets_dir / f"quote_packet_{packet_id}.yaml"
    existing_packet = None
    if args.packet_id:
        if not packet_file.exists():
            fail(f"packet not found: {packet_id}")
        existing_packet = load_structured_file(packet_file) or {}

    payload = build_payload_from_args(args, existing_packet)
    if not payload.get("customer_query") and not (payload.get("customer_ref") or {}).get("customer_query") and not (payload.get("customer_ref") or {}).get("customer_id"):
        fail("either --customer, --evidence-file, or --evidence-json must provide customer identity context")

    timestamp = now_utc()
    capability_name = current_capability_name()
    created_at = (existing_packet or {}).get("created_at") or timestamp
    created_by = (existing_packet or {}).get("created_by") or capability_name
    receipts = append_receipt((existing_packet or {}).get("receipts") or [], capability_name, timestamp)

    packet, decisions = build_packet(
        packet_id=packet_id,
        payload=payload,
        timestamp=timestamp,
        created_at=created_at,
        created_by=created_by,
        receipts=receipts,
        skip_stock=args.skip_stock_check,
        skip_pricing=args.skip_pricing,
        skip_customer_resolve=args.skip_customer_resolve,
        spine_root=spine_root,
        mint_modules_root=mint_modules_root,
    )

    dump_yaml(packet_file, packet)
    update_index(index_file, packet, timestamp)

    blocking_gaps = [gap for gap in packet.get("open_gaps", []) if gap.get("severity") == "blocking"]
    readiness = dict(packet.get("quote_readiness") or {})
    print(f"quote_packet_id: {packet_id}")
    print(f"state: {packet['state']}")
    print(f"quote_readiness_state: {readiness.get('state') or ''}")
    print(f"quote_next_step: {readiness.get('next_step') or ''}")
    print("confidence:")
    for key, value in packet.get("confidence", {}).items():
        print(f"  {key}: {value}")
    print("decisions:")
    print(f"  clarification_required: {str(any(gap['gap_type'] == 'clarification_required' for gap in packet['open_gaps'])).lower()}")
    print(f"  artie_route_allowed: {str(decisions['artie_route_allowed']).lower()}")
    print(f"  pricing_ready_allowed: {str(decisions['pricing_ready_allowed']).lower()}")
    print(f"  ready_for_review_allowed: {str(decisions['ready_for_review_allowed']).lower()}")
    print("open_gaps:")
    if not packet.get("open_gaps"):
        print("  - (none)")
    else:
        for gap in packet["open_gaps"]:
            print(f"  - {gap['gap_type']} ({gap['severity']}): {gap['description']}")
    print(f"blocking_gap_count: {len(blocking_gaps)}")
    print(f"packet_file: {packet_file}")
    print(f"index_file: {index_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
