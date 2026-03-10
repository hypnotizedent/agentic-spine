#!/usr/bin/env python3
"""Resolve supplier blank truth into a governed quote_packet."""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

from quote_packet_normalize import (
    add_gap,
    append_receipt,
    dump_yaml,
    fail,
    has_canonical_value,
    load_structured_file,
    now_utc,
    overall_confidence,
    update_index,
)


TERMINAL_STATES = {"sent", "paid", "closed"}
TRANSIENT_SUPPLIER_GAP_TYPES = {"supplier_unresolved", "stock_unavailable"}
TRANSIENT_SUPPLIER_GAP_PREFIXES = (
    "Supplier sourcing failed for ",
    "Stock unavailable for ",
)
STYLE_TOKEN_PATTERN = re.compile(r"\b[A-Z]{1,4}\d{2,6}[A-Z0-9-]*\b")
DEFAULT_SIZE_PRIORITY = ["L", "M", "XL", "S", "OSFA", "ONE SIZE", "XS", "2XL", "3XL", "4XL"]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-source",
        description="Resolve supplier blank truth and stock evidence into a governed quote_packet.",
    )
    parser.add_argument("packet_id", help="quote_packet_id to enrich")
    parser.add_argument("--search-limit", type=int, default=50, help="Supplier search result limit")
    parser.add_argument("--timeout-seconds", type=int, default=45, help="HTTP timeout for supplier calls")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.packet.source"


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


def packet_file_for_id(packets_dir: Path, packet_id: str) -> Path:
    return packets_dir / f"quote_packet_{packet_id}.yaml"


def canonical_suppliers_base_url(spine_root: Path) -> str:
    override = os.environ.get("SUPPLIERS_BASE_URL")
    if override:
        return override.rstrip("/")

    services_file = spine_root / "ops/bindings/services.health.yaml"
    if services_file.exists():
        services = load_structured_file(services_file) or {}
        for endpoint in services.get("endpoints") or []:
            if not isinstance(endpoint, dict) or endpoint.get("id") != "suppliers-v2":
                continue
            raw_url = str(endpoint.get("url") or "").strip()
            if not raw_url:
                continue
            parsed = urlparse.urlparse(raw_url)
            if parsed.scheme and parsed.netloc:
                return f"{parsed.scheme}://{parsed.netloc}"

    return "http://192.168.1.213:3800"


def resolve_suppliers_api_key(spine_root: Path) -> str:
    env_value = os.environ.get("SUPPLIERS_API_KEY", "").strip()
    if env_value:
        return env_value

    infisical_agent = spine_root / "ops/plugins/providers/bin/infisical-agent.sh"
    if not infisical_agent.exists():
        return ""

    result = subprocess.run(
        [str(infisical_agent), "get-cached", "infrastructure", "prod", "SUPPLIERS_API_KEY"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def normalize_supplier_code(value: str | None) -> str | None:
    mapping = {
        "sanmar": "sanmar",
        "san-mar": "sanmar",
        "ssactive": "ssactive",
        "ssactivewear": "ssactive",
        "ss-activewear": "ssactive",
        "s&s": "ssactive",
        "as_colour": "as_colour",
        "ascolour": "as_colour",
        "ascolor": "as_colour",
        "as-colour": "as_colour",
    }
    token = str(value or "").strip().lower()
    return mapping.get(token)


def normalize_brand_token(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]", "", str(value or "").strip().lower())


def normalize_style_token(value: str | None) -> str:
    return re.sub(r"[^A-Z0-9]", "", str(value or "").strip().upper())


def normalize_color_token(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]", "", str(value or "").strip().lower())


def normalize_size_token(value: str | None) -> str:
    return str(value or "").strip().upper()


def humanize_token(value: str) -> str:
    return value.replace("_", " ").replace("-", " ").strip()


def describe_line_item(item: dict[str, Any]) -> str:
    return str(item.get("description") or item.get("product_type") or item.get("line_item_id") or "line item")


def supplier_fields_snapshot(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "supplier_code": item.get("supplier_code"),
        "supplier_sku": item.get("supplier_sku"),
        "style_code": item.get("style_code"),
        "brand": item.get("brand"),
        "color": item.get("color"),
        "canonical_style_key": item.get("canonical_style_key"),
        "supplier_source": item.get("supplier_source"),
        "blanks_cost_cents": item.get("blanks_cost_cents"),
        "source_confidence": item.get("source_confidence"),
    }


def prune_transient_supplier_gaps(gaps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    retained: list[dict[str, Any]] = []
    for gap in gaps:
        if not isinstance(gap, dict):
            continue
        gap_type = str(gap.get("gap_type") or "")
        description = str(gap.get("description") or "")
        if gap_type in TRANSIENT_SUPPLIER_GAP_TYPES:
            continue
        if any(description.startswith(prefix) for prefix in TRANSIENT_SUPPLIER_GAP_PREFIXES):
            continue
        retained.append(copy.deepcopy(gap))
    return retained


def reset_gap_ids(gaps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    for idx, gap in enumerate(gaps, start=1):
        gap["gap_id"] = idx
    return gaps


def query_candidates(item: dict[str, Any]) -> list[tuple[str, str]]:
    queries: list[tuple[str, str]] = []
    supplier_sku = str(item.get("supplier_sku") or "").strip().upper()
    if supplier_sku:
        queries.append((supplier_sku, "supplier_sku"))

    style_code = str(item.get("style_code") or "").strip().upper()
    if style_code and style_code != supplier_sku:
        queries.append((style_code, "style_code"))

    for field, reason in (("description", "derived_style_code"), ("operator_notes", "derived_style_code")):
        match = STYLE_TOKEN_PATTERN.search(str(item.get(field) or "").upper())
        if match:
            token = match.group(0)
            if token not in {query for query, _ in queries}:
                queries.append((token, reason))

    return queries


def preferred_size(item: dict[str, Any]) -> str | None:
    size_breakdown = item.get("size_breakdown")
    if isinstance(size_breakdown, dict) and size_breakdown:
        ranked = sorted(
            ((normalize_size_token(size), int(qty or 0)) for size, qty in size_breakdown.items()),
            key=lambda entry: (-entry[1], DEFAULT_SIZE_PRIORITY.index(entry[0]) if entry[0] in DEFAULT_SIZE_PRIORITY else len(DEFAULT_SIZE_PRIORITY)),
        )
        if ranked and ranked[0][0]:
            return ranked[0][0]
    return DEFAULT_SIZE_PRIORITY[0]


def search_suppliers(base_url: str, api_key: str, query: str, limit: int, timeout_seconds: int) -> dict[str, Any]:
    encoded_query = urlparse.quote(query)
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/v1/suppliers/search?q={encoded_query}&limit={limit}",
        headers={"Accept": "application/json", "X-API-Key": api_key},
        method="GET",
    )
    with urlrequest.urlopen(request, timeout=timeout_seconds) as response:
        payload = response.read().decode("utf-8")
    return json.loads(payload or "{}")


def fetch_stock(base_url: str, api_key: str, supplier_code: str, supplier_sku: str, timeout_seconds: int) -> dict[str, Any]:
    encoded_sku = urlparse.quote(supplier_sku)
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}/api/v1/suppliers/{supplier_code}/products/{encoded_sku}/stock",
        headers={"Accept": "application/json", "X-API-Key": api_key},
        method="GET",
    )
    with urlrequest.urlopen(request, timeout=timeout_seconds) as response:
        payload = response.read().decode("utf-8")
    return json.loads(payload or "{}")


def filtered_candidates(item: dict[str, Any], query: str, reason: str, raw_results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    supplier_filter = normalize_supplier_code(str(item.get("supplier_code") or ""))
    style_filter = normalize_style_token(str(item.get("style_code") or query))
    brand_filter = normalize_brand_token(str(item.get("brand") or ""))
    color_filter = normalize_color_token(str(item.get("color") or ""))
    size_filter = preferred_size(item)

    candidates = [candidate for candidate in raw_results if isinstance(candidate, dict)]
    if supplier_filter:
        supplier_matched = [candidate for candidate in candidates if normalize_supplier_code(str(candidate.get("supplier_code") or "")) == supplier_filter]
        if supplier_matched:
            candidates = supplier_matched

    if reason in {"supplier_sku", "style_code", "derived_style_code"}:
        exact_style = [
            candidate
            for candidate in candidates
            if normalize_style_token(str(candidate.get("style_code") or "")) == style_filter
            or normalize_style_token(str(candidate.get("supplier_sku") or "")) == style_filter
        ]
        if exact_style:
            candidates = exact_style

    if brand_filter:
        brand_matched = [candidate for candidate in candidates if normalize_brand_token(str(candidate.get("brand") or "")) == brand_filter]
        if brand_matched:
            candidates = brand_matched

    if color_filter:
        color_matched = [candidate for candidate in candidates if normalize_color_token(str(candidate.get("color_name") or "")) == color_filter]
        if color_matched:
            candidates = color_matched

    if size_filter:
        size_matched = [candidate for candidate in candidates if normalize_size_token(str(candidate.get("size_name") or "")) == size_filter]
        if size_matched:
            candidates = size_matched

    return candidates


def source_confidence(reason: str) -> str:
    if reason in {"supplier_sku", "style_code"}:
        return "high"
    if reason == "derived_style_code":
        return "medium"
    return "low"


def selection_reason(item: dict[str, Any], query: str, reason: str, candidate: dict[str, Any]) -> str:
    details = [f"query={query}", f"match={reason}"]
    if item.get("color"):
        details.append(f"color={item['color']}")
    size_name = str(candidate.get("size_name") or "").strip()
    if size_name:
        details.append(f"size={size_name}")
    return ", ".join(details)


def stock_state_from_entries(entries: list[dict[str, Any]]) -> str:
    if not entries:
        return "blocked_supplier_unresolved"
    if any(entry.get("stock_check_state") in {"service_unavailable", "api_call_failed"} for entry in entries):
        return "partial"
    if any(entry.get("stock_check_state") == "not_requested_quantity_missing" for entry in entries):
        return "sourced_without_stock"
    return "completed"


def sync_confidence(packet: dict[str, Any], inventory_snapshot: dict[str, Any]) -> None:
    confidence = copy.deepcopy(packet.get("confidence") or {})
    customer_conf = str(confidence.get("customer_confidence") or "none")
    artwork_conf = str(confidence.get("artwork_confidence") or "none")
    pricing_conf = str(confidence.get("pricing_confidence") or "none")
    stock_conf = "none"
    if inventory_snapshot.get("stock_check_state") == "completed":
        stock_conf = "high"
    elif inventory_snapshot.get("supplier_results"):
        stock_conf = "medium"

    confidence["stock_confidence"] = stock_conf
    confidence["overall"] = overall_confidence(customer_conf, artwork_conf, stock_conf, pricing_conf, packet.get("open_gaps") or [])
    packet["confidence"] = confidence


def sync_state(packet: dict[str, Any]) -> None:
    if packet.get("state") in TERMINAL_STATES:
        return
    blocking_gaps = [gap for gap in packet.get("open_gaps") or [] if gap.get("severity") == "blocking"]
    packet["state"] = "needs_input" if blocking_gaps else "drafting"


def clear_stale_downstream_artifacts(packet: dict[str, Any], sourced_changed: bool) -> None:
    if not sourced_changed:
        return
    packet.pop("pricing_snapshot", None)
    packet.pop("quote_draft_ref", None)
    packet.pop("payment_ref", None)
    for item in packet.get("line_items") or []:
        if isinstance(item, dict):
            item.pop("pricing_snapshot_id", None)


def print_blocking_reasons(packet: dict[str, Any]) -> None:
    blocking = [gap for gap in packet.get("open_gaps") or [] if gap.get("severity") == "blocking"]
    if not blocking:
        return
    print("blocking_reasons:")
    for gap in blocking:
        print(f"  - {gap.get('description')}")


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
        stop(f"cannot source packet in terminal state {packet['state']}")

    line_items = [item for item in (packet.get("line_items") or []) if isinstance(item, dict)]
    if not line_items:
        fail("quote_packet has no line_items to source")

    timestamp = now_utc()
    capability_name = current_capability_name()
    gaps = prune_transient_supplier_gaps(packet.get("open_gaps") or [])

    api_key = resolve_suppliers_api_key(spine_root)
    if not api_key:
        add_gap(
            gaps,
            "supplier_unresolved",
            "SUPPLIERS_API_KEY is unavailable for governed packet sourcing",
            "blocking",
            "Provide supplier API access before sourcing garments",
            timestamp,
        )
        inventory_snapshot = {
            "snapshot_timestamp": timestamp,
            "supplier_results": [],
            "stock_check_state": "api_key_unavailable",
            "stock_warnings": ["Supplier API key unavailable"],
            "supplier_receipt_refs": [],
        }
        packet["inventory_snapshot"] = inventory_snapshot
        packet["open_gaps"] = reset_gap_ids(gaps)
        packet["updated_at"] = timestamp
        packet["receipts"] = append_receipt(packet.get("receipts") or [], capability_name, timestamp)
        sync_confidence(packet, inventory_snapshot)
        sync_state(packet)
        dump_yaml(packet_file, packet)
        update_index(index_file, packet, timestamp)
        print(f"quote_packet_id: {packet['quote_packet_id']}")
        print(f"state: {packet['state']}")
        print("source_state: api_key_unavailable")
        print("sourced_line_item_count: 0")
        print(f"blocking_gap_count: {len([gap for gap in packet['open_gaps'] if gap.get('severity') == 'blocking'])}")
        print_blocking_reasons(packet)
        print(f"packet_file: {packet_file}")
        return 0

    base_url = canonical_suppliers_base_url(spine_root)
    supplier_results: list[dict[str, Any]] = []
    stock_warnings: list[str] = []
    sourced_line_item_count = 0
    sourced_changed = False

    for item in line_items:
        original_supplier_fields = supplier_fields_snapshot(item)
        label = describe_line_item(item)
        queries = query_candidates(item)
        if not queries:
            add_gap(
                gaps,
                "supplier_unresolved",
                f"Supplier sourcing failed for {label}: no canonical style code or SKU was available",
                "blocking",
                "Add style_code, supplier_sku, or other canonical blank identifier before sourcing",
                timestamp,
            )
            stock_warnings.append(f"{label}: no canonical style query available")
            continue

        selected_candidate: dict[str, Any] | None = None
        selected_reason = ""
        selected_query = ""
        for query, reason in queries:
            try:
                response = search_suppliers(base_url, api_key, query, args.search_limit, args.timeout_seconds)
            except urlerror.HTTPError as exc:
                add_gap(
                    gaps,
                    "supplier_unresolved",
                    f"Supplier sourcing failed for {label}: supplier search returned HTTP {exc.code}",
                    "blocking",
                    "Retry sourcing after supplier search succeeds",
                    timestamp,
                )
                stock_warnings.append(f"{label}: supplier search HTTP {exc.code}")
                break
            except urlerror.URLError as exc:
                add_gap(
                    gaps,
                    "supplier_unresolved",
                    f"Supplier sourcing failed for {label}: supplier search unavailable ({exc.reason})",
                    "blocking",
                    "Retry sourcing after supplier search connectivity is restored",
                    timestamp,
                )
                stock_warnings.append(f"{label}: supplier search unavailable")
                break

            raw_results = response.get("results") or []
            candidates = filtered_candidates(item, query, reason, raw_results)
            if not candidates:
                continue
            selected_candidate = candidates[0]
            selected_reason = reason
            selected_query = query
            break

        if not selected_candidate:
            add_gap(
                gaps,
                "supplier_unresolved",
                f"Supplier sourcing failed for {label}: no trustworthy supplier candidate matched the packet truth",
                "blocking",
                "Refine style/brand/color details or choose a supplier manually",
                timestamp,
            )
            stock_warnings.append(f"{label}: no candidate match")
            continue

        supplier_code = normalize_supplier_code(str(selected_candidate.get("supplier_code") or ""))
        supplier_sku = str(selected_candidate.get("supplier_sku") or "").strip()
        piece_price = selected_candidate.get("piece_price")
        if not supplier_code or not supplier_sku or piece_price in (None, ""):
            add_gap(
                gaps,
                "supplier_unresolved",
                f"Supplier sourcing failed for {label}: selected candidate lacked canonical blank pricing truth",
                "blocking",
                "Choose a supplier candidate with supplier_code, supplier_sku, and piece_price",
                timestamp,
            )
            stock_warnings.append(f"{label}: selected candidate missing price truth")
            continue

        item["supplier_code"] = supplier_code
        item["supplier_sku"] = supplier_sku
        item["style_code"] = str(selected_candidate.get("style_code") or item.get("style_code") or supplier_sku)
        if selected_candidate.get("brand"):
            item["brand"] = selected_candidate["brand"]
        if selected_candidate.get("color_name"):
            item["color"] = selected_candidate["color_name"]
        if selected_candidate.get("canonical_style_key"):
            item["canonical_style_key"] = selected_candidate["canonical_style_key"]
        item["supplier_source"] = supplier_code
        item["blanks_cost_cents"] = round(float(piece_price) * 100)
        item["source_confidence"] = source_confidence(selected_reason)

        result_entry: dict[str, Any] = {
            "line_item_id": item.get("line_item_id"),
            "supplier_code": supplier_code,
            "supplier_sku": supplier_sku,
            "style_code": item.get("style_code"),
            "brand": item.get("brand"),
            "color": item.get("color"),
            "piece_price": float(piece_price),
            "blanks_cost_cents": item["blanks_cost_cents"],
            "selection_reason": selection_reason(item, selected_query, selected_reason, selected_candidate),
            "source_confidence": item["source_confidence"],
            "stock_check_state": "not_requested_quantity_missing",
        }

        if has_canonical_value(item.get("quantity")):
            try:
                stock_response = fetch_stock(base_url, api_key, supplier_code, supplier_sku, args.timeout_seconds)
            except urlerror.HTTPError as exc:
                result_entry["stock_check_state"] = "api_call_failed"
                result_entry["stock_error"] = f"HTTP {exc.code}"
                stock_warnings.append(f"{label}: stock lookup HTTP {exc.code}")
            except urlerror.URLError as exc:
                result_entry["stock_check_state"] = "service_unavailable"
                result_entry["stock_error"] = str(exc.reason)
                stock_warnings.append(f"{label}: stock lookup unavailable")
            else:
                total_available = int(stock_response.get("total_available") or 0)
                quantity = int(item.get("quantity") or 0)
                result_entry["stock_check_state"] = "completed"
                result_entry["total_available"] = total_available
                result_entry["stock_available"] = total_available >= quantity
                result_entry["warehouse_fidelity"] = copy.deepcopy(stock_response.get("warehouse_fidelity") or {})
                result_entry["variants"] = copy.deepcopy(stock_response.get("variants") or [])
                item["inventory_as_of_utc"] = timestamp
                if total_available < quantity:
                    add_gap(
                        gaps,
                        "stock_unavailable",
                        f"Stock unavailable for {label}: need {quantity}, supplier snapshot shows {total_available}",
                        "blocking",
                        "Choose another blank or reduce quantity before review",
                        timestamp,
                    )
        else:
            stock_warnings.append(f"{label}: quantity missing, stock not checked")

        supplier_results.append(result_entry)
        sourced_line_item_count += 1
        if supplier_fields_snapshot(item) != original_supplier_fields:
            sourced_changed = True

    inventory_snapshot = {
        "snapshot_timestamp": timestamp,
        "supplier_results": supplier_results,
        "stock_check_state": stock_state_from_entries(supplier_results),
        "stock_warnings": stock_warnings,
        "supplier_receipt_refs": [],
    }

    packet["line_items"] = line_items
    packet["inventory_snapshot"] = inventory_snapshot
    packet["open_gaps"] = reset_gap_ids(gaps)
    packet["updated_at"] = timestamp
    packet["receipts"] = append_receipt(packet.get("receipts") or [], capability_name, timestamp)
    clear_stale_downstream_artifacts(packet, sourced_changed)
    sync_confidence(packet, inventory_snapshot)
    sync_state(packet)
    if packet.get("state") == "drafting" and sourced_changed:
        packet.pop("customer_message_draft", None)

    dump_yaml(packet_file, packet)
    update_index(index_file, packet, timestamp)

    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"state: {packet['state']}")
    print(f"source_state: {inventory_snapshot['stock_check_state']}")
    print(f"sourced_line_item_count: {sourced_line_item_count}")
    print(f"blocking_gap_count: {len([gap for gap in packet['open_gaps'] if gap.get('severity') == 'blocking'])}")
    print_blocking_reasons(packet)
    print(f"packet_file: {packet_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
