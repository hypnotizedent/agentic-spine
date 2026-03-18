#!/usr/bin/env python3
"""Read-only production readiness check over canonical Mint order truth."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import yaml

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root
from quote_packet_normalize import fail, load_structured_file, now_utc, pricing_missing_fields, stop


ALLOWED_LIFECYCLE_STATES = {"approved", "production"}
READY_PAYMENT_STATE = "paid"
ART_REQUIRED_METHODS = {"screen_print", "embroidery", "engraving", "transfers"}
METHOD_PRODUCTION_EXTENSIONS: dict[str, set[str]] = {
    "screen_print": {"eps", "pdf", "ai", "svg"},
    "engraving": {"eps", "pdf", "ai", "svg"},
    "transfers": {"gtpl", "eps", "pdf", "ai", "svg", "png"},
    "embroidery": {"dst", "u00"},
}
METHOD_NEAR_READY_EXTENSIONS: dict[str, set[str]] = {
    "embroidery": {"emb", "pxf", "edr"},
}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="production-readiness-check",
        description="Evaluate whether canonical order truth is ready for governed production handoff.",
    )
    parser.add_argument("order_id", help="Canonical order_id to evaluate")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of YAML")
    return parser.parse_args(argv)


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


def parse_asset_extension(asset_ref: str) -> str:
    candidate = str(asset_ref or "").strip()
    if not candidate:
        return ""
    parsed = urlparse(candidate)
    path = parsed.path or candidate
    suffix = Path(path).suffix.lower()
    return suffix[1:] if suffix.startswith(".") else suffix


def humanize_extensions(values: set[str]) -> str:
    if not values:
        return "none"
    return ", ".join(f".{value}" for value in sorted(values))


def binding_for_line(
    line: dict[str, Any],
    revision_bindings: dict[str, dict[str, Any]],
) -> dict[str, Any] | None:
    binding_ref = str(line.get("artwork_binding_ref") or "").strip()
    if binding_ref and binding_ref in revision_bindings:
        return revision_bindings[binding_ref]

    order_line_id = str(line.get("order_line_id") or "").strip()
    if not order_line_id:
        return None

    for binding in revision_bindings.values():
        if str(binding.get("order_line_id") or "").strip() == order_line_id:
            return binding
    return None


def inferred_target_class(method: str, extensions: set[str]) -> str:
    if method == "embroidery":
        return "barudan"
    if method == "screen_print":
        return "screen_print_press"
    if method == "engraving":
        return "engraving"
    if method == "transfers":
        if "gtpl" in extensions:
            return "gtx"
        if "eps" in extensions:
            return "screenpro"
        if extensions:
            return "transfer_rip"
        return "transfers"
    return "unknown"


def compatible_assets(method: str, asset_refs: list[str]) -> tuple[list[str], list[str], set[str]]:
    extensions = {parse_asset_extension(ref) for ref in asset_refs if parse_asset_extension(ref)}
    accepted = METHOD_PRODUCTION_EXTENSIONS.get(method) or set()
    near_ready = METHOD_NEAR_READY_EXTENSIONS.get(method) or set()
    ready_refs = [ref for ref in asset_refs if parse_asset_extension(ref) in accepted]
    near_ready_refs = [ref for ref in asset_refs if parse_asset_extension(ref) in near_ready]
    return ready_refs, near_ready_refs, extensions


def evaluate_line(line: dict[str, Any], revision_bindings: dict[str, dict[str, Any]]) -> dict[str, Any]:
    blockers: list[str] = []
    warnings: list[str] = []

    order_line_id = str(line.get("order_line_id") or "").strip()
    method = str(line.get("decoration_method") or "").strip()
    line_for_contract = dict(line)
    if order_line_id and not line_for_contract.get("line_item_id"):
        line_for_contract["line_item_id"] = order_line_id
    missing_fields = pricing_missing_fields(line_for_contract)
    if missing_fields:
        blockers.append(f"line is missing governed production inputs: {', '.join(missing_fields)}")

    binding = binding_for_line(line, revision_bindings)
    binding_id = str((binding or {}).get("artwork_binding_id") or "")
    selection_state = str((binding or {}).get("selection_state") or "")
    asset_refs = [str(ref) for ref in ((binding or {}).get("asset_refs") or []) if str(ref or "").strip()]

    if method in ART_REQUIRED_METHODS:
        if binding is None:
            blockers.append("no artwork_binding is attached for an artwork-requiring decoration method")
        else:
            if selection_state != "approved":
                blockers.append(f"artwork_binding selection_state is {selection_state or 'missing'} (must be approved)")
            ready_refs, near_ready_refs, seen_extensions = compatible_assets(method, asset_refs)
            if ready_refs:
                production_asset_refs = ready_refs
            else:
                production_asset_refs = []
                extension_hint = humanize_extensions(seen_extensions)
                blockers.append(
                    f"artwork_binding lacks a method-compatible production asset for {method} (found {extension_hint})"
                )
                if near_ready_refs:
                    warnings.append(
                        f"near-ready asset exists but machine-ready export is still missing: {humanize_extensions({parse_asset_extension(ref) for ref in near_ready_refs})}"
                    )
    else:
        production_asset_refs = asset_refs
        seen_extensions = {parse_asset_extension(ref) for ref in asset_refs if parse_asset_extension(ref)}

    line_state = "ready" if not blockers else "blocked"
    return {
        "order_line_id": order_line_id,
        "description": line.get("description") or line.get("product_type") or order_line_id,
        "product_type": line.get("product_type"),
        "decoration_method": method or None,
        "inferred_target_class": inferred_target_class(method, seen_extensions),
        "readiness_state": line_state,
        "artwork_binding_id": binding_id or None,
        "artwork_selection_state": selection_state or None,
        "production_asset_refs": production_asset_refs,
        "blocking_reasons": blockers,
        "warning_reasons": warnings,
    }


def dedupe_strings(values: list[str]) -> list[str]:
    seen = set()
    output: list[str] = []
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        output.append(value)
    return output


def recommended_next_step(summary: dict[str, Any]) -> str:
    lifecycle_state = str(summary["order_state"]["lifecycle_state"] or "")
    payment_state = str(summary["order_state"]["payment_state"] or "")
    blockers = summary["blocking_reasons"]

    if not blockers:
        if lifecycle_state == "production":
            return "order already in production"
        return "mint.production.handoff.create"

    if payment_state != READY_PAYMENT_STATE:
        return "collect full payment and reconcile canonical order payment state"
    if lifecycle_state not in ALLOWED_LIFECYCLE_STATES:
        return "advance canonical order lifecycle to approved before production handoff"
    if any("selection_state" in blocker for blocker in blockers):
        return "resolve artwork approval and rerun mint.production.readiness.check"
    if any("production asset" in blocker for blocker in blockers):
        return "compile method-compatible production files and rerun mint.production.readiness.check"
    return "resolve canonical production blockers and rerun mint.production.readiness.check"


def build_readiness_summary(
    order_id: str,
    orders_dir: Path,
    order_revisions_dir: Path,
    artwork_bindings_dir: Path,
) -> dict[str, Any]:
    order_file = entity_file(orders_dir, "order", order_id)
    if not order_file.exists():
        fail(f"canonical order not found: {order_id}")

    order = load_structured_file(order_file) or {}
    if not isinstance(order, dict):
        fail(f"order is not a valid object: {order_id}")

    order_revision_id = str(order.get("current_revision_id") or "").strip()
    if not order_revision_id:
        fail(f"order is missing current_revision_id: {order_id}")

    order_revision_file = entity_file(order_revisions_dir, "order_revision", order_revision_id)
    if not order_revision_file.exists():
        fail(f"canonical order_revision not found: {order_revision_id}")

    order_revision = load_structured_file(order_revision_file) or {}
    if not isinstance(order_revision, dict):
        fail(f"order_revision is not a valid object: {order_revision_id}")

    line_items = [item for item in (order_revision.get("line_items") or []) if isinstance(item, dict)]
    if not isinstance(order_revision.get("line_items") or [], list):
        fail(f"order_revision line_items must be a list: {order_revision_id}")

    binding_refs = []
    for value in order_revision.get("artwork_binding_refs") or []:
        ref = str(value or "").strip()
        if ref and ref not in binding_refs:
            binding_refs.append(ref)
    for line in line_items:
        ref = str(line.get("artwork_binding_ref") or "").strip()
        if ref and ref not in binding_refs:
            binding_refs.append(ref)

    revision_bindings: dict[str, dict[str, Any]] = {}
    for binding_ref in binding_refs:
        binding_file = entity_file(artwork_bindings_dir, "artwork_binding", binding_ref)
        if binding_file.exists():
            binding = load_structured_file(binding_file) or {}
            if isinstance(binding, dict):
                revision_bindings[binding_ref] = binding

    blockers: list[str] = []
    warnings: list[str] = []

    lifecycle_state = str(order.get("lifecycle_state") or "")
    payment_state = str(order.get("payment_state") or "")
    if lifecycle_state not in ALLOWED_LIFECYCLE_STATES:
        blockers.append(f"order lifecycle_state is {lifecycle_state or 'missing'} (must be approved or production)")
    if payment_state != READY_PAYMENT_STATE:
        blockers.append(f"order payment_state is {payment_state or 'missing'} (must be paid)")
    if not line_items:
        blockers.append("current order_revision has no line_items")

    evaluated_lines = [evaluate_line(line, revision_bindings) for line in line_items]
    for line in evaluated_lines:
        blockers.extend(line["blocking_reasons"])
        warnings.extend(line["warning_reasons"])

    target_classes = sorted(
        {
            str(line.get("inferred_target_class") or "")
            for line in evaluated_lines
            if str(line.get("inferred_target_class") or "")
        }
    )

    summary = {
        "checked_at": now_utc(),
        "order_id": order_id,
        "order_revision_id": order_revision_id,
        "production_readiness_state": "ready" if not blockers else "blocked",
        "order_state": {
            "lifecycle_state": lifecycle_state or None,
            "payment_state": payment_state or None,
            "active_quote_id": order.get("active_quote_id") or None,
        },
        "target_classes": target_classes,
        "blocking_reasons": dedupe_strings(blockers),
        "warning_reasons": dedupe_strings(warnings),
        "lines": evaluated_lines,
    }
    summary["recommended_next_step"] = recommended_next_step(summary)
    return summary


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    spine_root = resolve_spine_root(__file__)
    mint_root = resolve_mint_data_root(spine_root=spine_root, current_file=__file__)

    orders_dir = Path(os.environ.get("MINT_ORDER_RUNTIME_DIR") or (mint_root / "orders"))
    order_revisions_dir = Path(os.environ.get("MINT_ORDER_REVISIONS_DIR") or (mint_root / "order-revisions"))
    artwork_bindings_dir = Path(os.environ.get("MINT_ARTWORK_BINDINGS_DIR") or (mint_root / "artwork-bindings"))

    summary = build_readiness_summary(args.order_id, orders_dir, order_revisions_dir, artwork_bindings_dir)

    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=False))
    else:
        print(yaml.safe_dump({"production_readiness": summary}, sort_keys=False).strip())
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main(os.sys.argv[1:]))
