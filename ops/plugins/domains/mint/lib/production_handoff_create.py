#!/usr/bin/env python3
"""Create immutable governed Mint production handoff records from canonical order truth."""

from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
from typing import Any

import yaml

from production_readiness_check import build_readiness_summary, entity_file
from quote_packet_normalize import dump_yaml, fail, load_structured_file, now_utc, stop


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="production-handoff-create",
        description="Create an immutable governed Mint production handoff from canonical ready order truth.",
    )
    parser.add_argument("order_id", help="Canonical order_id to hand off")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of YAML")
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_PRODUCTION_HANDOFF_CAPABILITY_NAME") or "mint.production.handoff.create"


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


def dedupe_strings(values: list[str]) -> list[str]:
    seen = set()
    output: list[str] = []
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        output.append(value)
    return output


def handoff_id_for(order_id: str, order_revision_id: str) -> str:
    return f"{order_id}--{order_revision_id}"


def handoff_file_for(handoffs_dir: Path, production_handoff_id: str) -> Path:
    return handoffs_dir / f"production_handoff_{production_handoff_id}.yaml"


def summarize_line(
    line: dict[str, Any],
    readiness_line: dict[str, Any],
) -> dict[str, Any]:
    return {
        "order_line_id": line.get("order_line_id"),
        "product_type": line.get("product_type"),
        "description": line.get("description") or line.get("product_type") or line.get("order_line_id"),
        "quantity": line.get("quantity"),
        "brand": line.get("brand") or None,
        "style_code": line.get("style_code") or None,
        "color": line.get("color") or None,
        "decoration_method": line.get("decoration_method") or None,
        "placement": line.get("placement") or None,
        "print_locations": copy.deepcopy(line.get("print_locations") or []),
        "graphic_size_inches": copy.deepcopy(line.get("graphic_size_inches") or {}) or None,
        "size_breakdown": copy.deepcopy(line.get("size_breakdown") or {}) or None,
        "artwork_binding_id": readiness_line.get("artwork_binding_id") or line.get("artwork_binding_ref") or None,
        "artwork_selection_state": readiness_line.get("artwork_selection_state") or None,
        "inferred_target_class": readiness_line.get("inferred_target_class") or None,
        "production_asset_refs": copy.deepcopy(readiness_line.get("production_asset_refs") or []),
        "warning_reasons": copy.deepcopy(readiness_line.get("warning_reasons") or []),
    }


def build_handoff_record(
    order: dict[str, Any],
    order_revision: dict[str, Any],
    quote: dict[str, Any] | None,
    readiness: dict[str, Any],
    timestamp: str,
) -> dict[str, Any]:
    order_id = str(order.get("order_id") or "").strip()
    order_revision_id = str(order_revision.get("order_revision_id") or "").strip()
    production_handoff_id = handoff_id_for(order_id, order_revision_id)

    readiness_lines = {
        str(line.get("order_line_id") or "").strip(): line
        for line in (readiness.get("lines") or [])
        if isinstance(line, dict) and str(line.get("order_line_id") or "").strip()
    }

    handoff_lines: list[dict[str, Any]] = []
    production_asset_refs: list[str] = []
    artwork_binding_refs: list[str] = []
    for line in order_revision.get("line_items") or []:
        if not isinstance(line, dict):
            continue
        order_line_id = str(line.get("order_line_id") or "").strip()
        readiness_line = readiness_lines.get(order_line_id, {})
        line_snapshot = summarize_line(line, readiness_line)
        handoff_lines.append(line_snapshot)
        artwork_binding_id = str(line_snapshot.get("artwork_binding_id") or "").strip()
        if artwork_binding_id:
            artwork_binding_refs.append(artwork_binding_id)
        production_asset_refs.extend(
            [str(ref) for ref in (line_snapshot.get("production_asset_refs") or []) if str(ref or "").strip()]
        )

    return {
        "production_handoff_id": production_handoff_id,
        "handoff_state": "ready_for_staging",
        "created_at": timestamp,
        "created_by": current_capability_name(),
        "order_id": order_id,
        "order_revision_id": order_revision_id,
        "quote_id": str((quote or {}).get("quote_id") or "") or None,
        "source_quote_packet_id": str(order.get("source_quote_packet_id") or "") or None,
        "customer_ref": {
            "customer_id": order.get("customer_id") or None,
            "customer_name": order.get("customer_name") or None,
            "customer_email": order.get("customer_email") or None,
            "customer_identity_state": order.get("customer_identity_state") or None,
        },
        "order_state": {
            "lifecycle_state": order.get("lifecycle_state") or None,
            "payment_state": order.get("payment_state") or None,
            "active_quote_id": order.get("active_quote_id") or None,
        },
        "delivery_commitment": copy.deepcopy(order_revision.get("delivery_commitment") or {}) or None,
        "target_classes": copy.deepcopy(readiness.get("target_classes") or []),
        "artwork_binding_refs": dedupe_strings(artwork_binding_refs),
        "production_asset_refs": dedupe_strings(production_asset_refs),
        "warning_reasons": copy.deepcopy(readiness.get("warning_reasons") or []),
        "line_items": handoff_lines,
        "readiness_receipt": {
            "checked_at": readiness.get("checked_at") or None,
            "production_readiness_state": readiness.get("production_readiness_state") or None,
            "recommended_next_step": readiness.get("recommended_next_step") or None,
        },
    }


def build_summary(record: dict[str, Any], handoff_file: Path, create_state: str) -> dict[str, Any]:
    return {
        "production_handoff_id": record.get("production_handoff_id"),
        "handoff_create_state": create_state,
        "handoff_state": record.get("handoff_state"),
        "order_id": record.get("order_id"),
        "order_revision_id": record.get("order_revision_id"),
        "quote_id": record.get("quote_id"),
        "target_classes": copy.deepcopy(record.get("target_classes") or []),
        "artwork_binding_count": len(record.get("artwork_binding_refs") or []),
        "production_asset_count": len(record.get("production_asset_refs") or []),
        "production_handoff_file": str(handoff_file),
    }


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    spine_root = Path(os.environ.get("SPINE_ROOT") or script_dir.parent.parent.parent.parent)
    mint_root = Path(
        os.environ.get("MINT_DATA_ROOT")
        or os.environ.get("SPINE_DATA_ROOT")
        or os.environ.get("SPINE_DOMAIN_STATE")
        or (spine_root.parent / ".data")
    ) / "mint"

    orders_dir = Path(os.environ.get("MINT_ORDER_RUNTIME_DIR") or (mint_root / "orders"))
    order_revisions_dir = Path(os.environ.get("MINT_ORDER_REVISIONS_DIR") or (mint_root / "order-revisions"))
    quotes_dir = Path(os.environ.get("MINT_QUOTES_DIR") or (mint_root / "quotes"))
    artwork_bindings_dir = Path(os.environ.get("MINT_ARTWORK_BINDINGS_DIR") or (mint_root / "artwork-bindings"))
    handoffs_dir = Path(os.environ.get("MINT_PRODUCTION_HANDOFFS_DIR") or (mint_root / "production-handoffs"))
    handoffs_index_file = Path(
        os.environ.get("MINT_PRODUCTION_HANDOFFS_INDEX_FILE") or (mint_root / "production-handoffs-index.yaml")
    )

    order_file = entity_file(orders_dir, "order", args.order_id)
    if not order_file.exists():
        fail(f"canonical order not found: {args.order_id}")
    order = load_structured_file(order_file) or {}
    if not isinstance(order, dict):
        fail(f"order is not a valid object: {args.order_id}")

    readiness = build_readiness_summary(args.order_id, orders_dir, order_revisions_dir, artwork_bindings_dir)
    if readiness.get("production_readiness_state") != "ready":
        reasons = "; ".join(readiness.get("blocking_reasons") or [])
        stop(f"production readiness is blocked: {reasons}")

    order_revision_id = str(readiness.get("order_revision_id") or "").strip()
    order_revision_file = entity_file(order_revisions_dir, "order_revision", order_revision_id)
    if not order_revision_file.exists():
        fail(f"canonical order_revision not found: {order_revision_id}")
    order_revision = load_structured_file(order_revision_file) or {}
    if not isinstance(order_revision, dict):
        fail(f"order_revision is not a valid object: {order_revision_id}")

    quote: dict[str, Any] | None = None
    active_quote_id = str(order.get("active_quote_id") or "").strip()
    if active_quote_id:
        quote_file = entity_file(quotes_dir, "quote", active_quote_id)
        if not quote_file.exists():
            fail(f"canonical active quote not found: {active_quote_id}")
        quote = load_structured_file(quote_file) or {}
        if not isinstance(quote, dict):
            fail(f"quote is not a valid object: {active_quote_id}")

    handoffs_dir.mkdir(parents=True, exist_ok=True)
    production_handoff_id = handoff_id_for(args.order_id, order_revision_id)
    handoff_file = handoff_file_for(handoffs_dir, production_handoff_id)

    if handoff_file.exists():
        existing = load_structured_file(handoff_file) or {}
        if not isinstance(existing, dict):
            fail(f"production handoff is not a valid object: {production_handoff_id}")
        summary = build_summary(existing, handoff_file, "existing")
        update_entity_index(
            handoffs_index_file,
            "production_handoffs",
            "production_handoff_id",
            {
                "production_handoff_id": existing.get("production_handoff_id"),
                "order_id": existing.get("order_id"),
                "order_revision_id": existing.get("order_revision_id"),
                "quote_id": existing.get("quote_id"),
                "handoff_state": existing.get("handoff_state"),
                "created_at": existing.get("created_at"),
            },
        )
        if args.json:
            print(json.dumps(summary, indent=2, sort_keys=False))
        else:
            print(yaml.safe_dump({"production_handoff": summary}, sort_keys=False).strip())
        return 0

    timestamp = now_utc()
    record = build_handoff_record(order, order_revision, quote, readiness, timestamp)
    dump_yaml(handoff_file, record)
    update_entity_index(
        handoffs_index_file,
        "production_handoffs",
        "production_handoff_id",
        {
            "production_handoff_id": record["production_handoff_id"],
            "order_id": record["order_id"],
            "order_revision_id": record["order_revision_id"],
            "quote_id": record.get("quote_id"),
            "handoff_state": record["handoff_state"],
            "created_at": record["created_at"],
        },
    )

    summary = build_summary(record, handoff_file, "created")
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=False))
    else:
        print(yaml.safe_dump({"production_handoff": summary}, sort_keys=False).strip())
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main(os.sys.argv[1:]))
