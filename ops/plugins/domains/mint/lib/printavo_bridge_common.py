from __future__ import annotations

import copy
import csv
import json
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root as governed_resolve_spine_root
from quote_packet_normalize import dump_yaml, load_structured_file, now_utc


PRINTAVO_BRIDGE_NAMESPACE = uuid.uuid5(
    uuid.NAMESPACE_URL,
    "https://spine.ronny.works/mint/printavo-bridge",
)
PRINTAVO_STATES = {
    "needs_more_info_before_printavo",
    "drafted_in_printavo",
    "quote_live",
    "approved",
    "paid",
    "converted_to_work_order",
}
PRINTAVO_URL_PATTERN = re.compile(r"https?://[^\s\"'<>]+printavo\.com/[^\s\"'<>]+", re.IGNORECASE)


def normalize_text(value: Any) -> str:
    return str(value or "").strip()


def merge_unique_strings(*groups: Any) -> list[str]:
    merged: list[str] = []
    seen: set[str] = set()
    for group in groups:
        items = group if isinstance(group, (list, tuple, set)) else [group]
        for item in items:
            text = normalize_text(item)
            if not text or text in seen:
                continue
            seen.add(text)
            merged.append(text)
    return merged


def resolve_spine_root() -> Path:
    return governed_resolve_spine_root(__file__)


def resolve_mint_root(spine_root: Path | None = None) -> Path:
    return resolve_mint_data_root(spine_root=spine_root, current_file=__file__)


def runtime_paths(spine_root: Path | None = None) -> dict[str, Path]:
    mint_root = resolve_mint_root(spine_root)
    return {
        "mint_root": mint_root,
        "orders_dir": Path(os.environ.get("MINT_ORDER_RUNTIME_DIR") or (mint_root / "orders")),
        "orders_index_file": Path(os.environ.get("MINT_ORDER_INDEX_FILE") or (mint_root / "orders-index.yaml")),
        "quotes_dir": Path(os.environ.get("MINT_QUOTES_DIR") or (mint_root / "quotes")),
        "quotes_index_file": Path(os.environ.get("MINT_QUOTES_INDEX_FILE") or (mint_root / "quotes-index.yaml")),
        "printavo_bridges_dir": Path(os.environ.get("MINT_PRINTAVO_BRIDGES_DIR") or (mint_root / "printavo-bridges")),
        "printavo_bridges_index_file": Path(
            os.environ.get("MINT_PRINTAVO_BRIDGES_INDEX_FILE") or (mint_root / "printavo-bridges-index.yaml")
        ),
    }


def entity_file(entity_dir: Path, prefix: str, entity_id: str) -> Path:
    return entity_dir / f"{prefix}_{entity_id}.yaml"


def load_yaml_object(path: Path) -> dict[str, Any]:
    payload = load_structured_file(path) if path.exists() else {}
    return payload if isinstance(payload, dict) else {}


def load_index(index_file: Path, list_key: str) -> list[dict[str, Any]]:
    payload = load_structured_file(index_file) if index_file.exists() else {}
    if not isinstance(payload, dict):
        return []
    return [copy.deepcopy(item) for item in (payload.get(list_key) or []) if isinstance(item, dict)]


def update_entity_index(index_file: Path, list_key: str, entity_key: str, entry: dict[str, Any]) -> None:
    payload = load_structured_file(index_file) if index_file.exists() else {list_key: []}
    if not isinstance(payload, dict):
        payload = {list_key: []}
    entries = payload.setdefault(list_key, [])
    existing = next(
        (
            item
            for item in entries
            if isinstance(item, dict) and normalize_text(item.get(entity_key)) == normalize_text(entry.get(entity_key))
        ),
        None,
    )
    if existing:
        existing.update(copy.deepcopy(entry))
    else:
        entries.append(copy.deepcopy(entry))
    dump_yaml(index_file, payload)


def default_printavo_summary(state: str = "needs_more_info_before_printavo") -> dict[str, Any]:
    normalized_state = normalize_text(state) or "needs_more_info_before_printavo"
    if normalized_state not in PRINTAVO_STATES:
        normalized_state = "needs_more_info_before_printavo"
    return {
        "schema_version": "1.0",
        "printavo_state": normalized_state,
        "printavo_customer_id": None,
        "printavo_invoice_url": None,
        "printavo_public_invoice_url": None,
        "printavo_work_order_url": None,
        "printavo_visual_id": None,
        "last_reconciled_at": None,
        "source_kind": "none",
        "record_kind": "none",
        "record_id": None,
        "provenance": {"source": "none", "basis": []},
    }


def normalize_printavo_summary(order: dict[str, Any]) -> dict[str, Any]:
    summary = order.get("printavo_summary")
    if isinstance(summary, dict) and summary:
        normalized = copy.deepcopy(summary)
        default = default_printavo_summary(str(summary.get("printavo_state") or "needs_more_info_before_printavo"))
        for key, value in default.items():
            normalized.setdefault(key, copy.deepcopy(value))
        if normalize_text(normalized.get("printavo_state")) not in PRINTAVO_STATES:
            normalized["printavo_state"] = "needs_more_info_before_printavo"
        provenance = normalized.get("provenance")
        normalized["provenance"] = copy.deepcopy(provenance) if isinstance(provenance, dict) else {"source": "none", "basis": []}
        normalized["provenance"].setdefault("source", "none")
        normalized["provenance"].setdefault("basis", [])
        return normalized
    return default_printavo_summary()


def printavo_summary_from_bridge(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": "1.0",
        "printavo_state": normalize_text(record.get("printavo_state")) or "needs_more_info_before_printavo",
        "printavo_customer_id": normalize_text(record.get("printavo_customer_id")) or None,
        "printavo_invoice_url": normalize_text(record.get("printavo_invoice_url")) or None,
        "printavo_public_invoice_url": normalize_text(record.get("printavo_public_invoice_url")) or None,
        "printavo_work_order_url": normalize_text(record.get("printavo_work_order_url")) or None,
        "printavo_visual_id": normalize_text(record.get("printavo_visual_id")) or None,
        "last_reconciled_at": normalize_text(record.get("last_reconciled_at")) or None,
        "source_kind": normalize_text(record.get("source_kind")) or "none",
        "record_kind": "printavo_bridge",
        "record_id": normalize_text(record.get("printavo_bridge_id")) or None,
        "provenance": copy.deepcopy(record.get("provenance") or {"source": "none", "basis": []}),
    }


def printavo_bridge_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "printavo_bridge_id": record.get("printavo_bridge_id"),
        "seed_id": record.get("seed_id"),
        "order_id": record.get("order_id"),
        "quote_id": record.get("quote_id"),
        "customer_id": record.get("customer_id"),
        "customer_email": record.get("customer_email"),
        "customer_name": record.get("customer_name"),
        "printavo_customer_id": record.get("printavo_customer_id"),
        "printavo_invoice_url": record.get("printavo_invoice_url"),
        "printavo_public_invoice_url": record.get("printavo_public_invoice_url"),
        "printavo_work_order_url": record.get("printavo_work_order_url"),
        "printavo_visual_id": record.get("printavo_visual_id"),
        "printavo_state": record.get("printavo_state"),
        "source_kind": record.get("source_kind"),
        "source_quote_packet_id": record.get("source_quote_packet_id"),
        "last_reconciled_at": record.get("last_reconciled_at"),
        "recorded_at": record.get("recorded_at"),
        "evidence_refs": copy.deepcopy(record.get("evidence_refs") or []),
        "receipts": copy.deepcopy(record.get("receipts") or []),
    }


def bridge_id(
    *,
    seed_id: str,
    order_id: str,
    quote_id: str,
    printavo_customer_id: str,
    printavo_invoice_url: str,
    printavo_public_invoice_url: str,
    printavo_work_order_url: str,
    printavo_visual_id: str,
    printavo_state: str,
    source_kind: str,
) -> str:
    signature = json.dumps(
        {
            "seed_id": seed_id,
            "order_id": order_id,
            "quote_id": quote_id,
            "printavo_customer_id": printavo_customer_id,
            "printavo_invoice_url": printavo_invoice_url,
            "printavo_public_invoice_url": printavo_public_invoice_url,
            "printavo_work_order_url": printavo_work_order_url,
            "printavo_visual_id": printavo_visual_id,
            "printavo_state": printavo_state,
            "source_kind": source_kind,
        },
        sort_keys=True,
    )
    return str(uuid.uuid5(PRINTAVO_BRIDGE_NAMESPACE, signature))


def load_order(paths: dict[str, Path], order_id: str) -> tuple[Path, dict[str, Any]]:
    path = entity_file(paths["orders_dir"], "order", order_id)
    if not path.exists():
        raise FileNotFoundError(f"canonical order not found: {order_id}")
    payload = load_yaml_object(path)
    if not payload:
        raise ValueError(f"canonical order is not a valid object: {order_id}")
    return path, payload


def load_quote(paths: dict[str, Path], quote_id: str) -> tuple[Path, dict[str, Any]]:
    path = entity_file(paths["quotes_dir"], "quote", quote_id)
    if not path.exists():
        raise FileNotFoundError(f"canonical quote not found: {quote_id}")
    payload = load_yaml_object(path)
    if not payload:
        raise ValueError(f"canonical quote is not a valid object: {quote_id}")
    return path, payload


def resolve_order_context(paths: dict[str, Path], *, order_id: str = "", quote_id: str = "") -> tuple[Path, dict[str, Any], dict[str, Any] | None]:
    normalized_order_id = normalize_text(order_id)
    normalized_quote_id = normalize_text(quote_id)
    quote: dict[str, Any] | None = None
    if normalized_quote_id:
        _quote_file, quote = load_quote(paths, normalized_quote_id)
        normalized_order_id = normalize_text(quote.get("order_id"))
        if not normalized_order_id:
            raise ValueError("canonical quote is missing order_id")
    if not normalized_order_id:
        raise ValueError("either order_id or quote_id is required")
    order_file, order = load_order(paths, normalized_order_id)
    if quote is None:
        active_quote_id = normalize_text(order.get("active_quote_id"))
        if active_quote_id:
            try:
                _quote_file, quote = load_quote(paths, active_quote_id)
            except (FileNotFoundError, ValueError):
                quote = None
    return order_file, order, quote


def sync_order_printavo_projection(paths: dict[str, Path], order_file: Path, order: dict[str, Any], summary: dict[str, Any]) -> None:
    timestamp = normalize_text(summary.get("last_reconciled_at")) or now_utc()
    order["printavo_summary"] = copy.deepcopy(summary)
    order["updated_at"] = timestamp
    dump_yaml(order_file, order)
    try:
        from payment_record_common import order_index_entry  # noqa: PLC0415
    except Exception:  # pragma: no cover - defensive
        return
    update_entity_index(paths["orders_index_file"], "orders", "order_id", order_index_entry(order, timestamp))


def normalize_url(url: Any) -> str:
    value = normalize_text(url)
    return value.rstrip("/") if value else ""


def extract_invoice_number(text: Any) -> str:
    raw = normalize_text(text)
    if not raw:
        return ""
    match = re.search(r"\b(\d{3,})\b", raw)
    return match.group(1) if match else ""


def normalize_visual_id(value: Any) -> str:
    token = extract_invoice_number(value)
    return token or normalize_text(value)


def parse_timestamp(raw: Any) -> str:
    value = normalize_text(raw)
    if not value:
        return ""
    for fmt in (
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S.%fZ",
        "%Y-%m-%d %H:%M:%S %z",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
    ):
        try:
            parsed = datetime.strptime(value, fmt)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            return parsed.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except ValueError:
            continue
    return value


def latest_glob_path(pattern: str) -> Path | None:
    expanded = pattern.replace("$HOME", str(Path.home()))
    base = Path.home()
    static_parts: list[str] = []
    for part in Path(expanded).parts:
        if any(ch in part for ch in "*?[]"):
            break
        static_parts.append(part)
    if static_parts:
        base = Path(*static_parts)
    try:
        relative = str(Path(expanded).relative_to(base))
    except ValueError:
        relative = str(Path(expanded))
    matches = sorted(
        (path for path in base.glob(relative) if path.is_file()),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return matches[0] if matches else None


def resolve_orders_export() -> Path | None:
    override = normalize_text(os.environ.get("MINT_PRINTAVO_BRIDGE_ORDERS_EXPORT"))
    if override:
        path = Path(override).expanduser().resolve()
        return path if path.is_file() else None
    return latest_glob_path("$HOME/ronny-ops/mint-os/data/imports/**/*ExportsOrdersJob_export*.csv")


def load_orders_export_rows() -> tuple[Path | None, list[dict[str, str]]]:
    export_path = resolve_orders_export()
    if export_path is None:
        return None, []
    with export_path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = [dict(row) for row in csv.DictReader(handle)]
    return export_path, rows


def resolve_printavo_extract_root() -> Path | None:
    override = normalize_text(os.environ.get("MINT_PRINTAVO_BRIDGE_EXTRACT_ROOT"))
    if override:
        path = Path(override).expanduser().resolve()
        return path if path.is_dir() else None
    default = Path.home() / "ronny-ops" / "mint-os" / "apps" / "api" / "data" / "printavo-extraction-2025-01-07"
    return default if default.is_dir() else None


def load_extract_record(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return payload if isinstance(payload, dict) else {}


def recover_from_extract(
    *,
    visual_id: str = "",
    invoice_url: str = "",
    public_invoice_url: str = "",
) -> tuple[dict[str, Any], str]:
    root = resolve_printavo_extract_root()
    if root is None:
        return {}, ""
    candidates: list[Path] = []
    normalized_visual_id = normalize_visual_id(visual_id or invoice_url or public_invoice_url)
    if normalized_visual_id:
        for folder in ("invoices", "quotes"):
            candidate = root / folder / f"{normalized_visual_id}.json"
            if candidate.is_file():
                candidates.append(candidate)
    else:
        for folder in ("invoices", "quotes"):
            candidates.extend(sorted((root / folder).glob("*.json"))[:0])
    normalized_invoice_url = normalize_url(invoice_url)
    normalized_public_url = normalize_url(public_invoice_url)
    seen: set[Path] = set()
    for candidate in candidates:
        if candidate in seen:
            continue
        seen.add(candidate)
        payload = load_extract_record(candidate)
        if not payload:
            continue
        if normalized_visual_id and normalize_visual_id(payload.get("visualId")) == normalized_visual_id:
            return payload, str(candidate)
        if normalized_invoice_url and normalize_url(payload.get("url")) == normalized_invoice_url:
            return payload, str(candidate)
        if normalized_public_url and normalize_url(payload.get("publicUrl")) == normalized_public_url:
            return payload, str(candidate)

    for folder in ("invoices", "quotes"):
        for candidate in sorted((root / folder).glob("*.json")):
            payload = load_extract_record(candidate)
            if not payload:
                continue
            if normalized_invoice_url and normalize_url(payload.get("url")) == normalized_invoice_url:
                return payload, str(candidate)
            if normalized_public_url and normalize_url(payload.get("publicUrl")) == normalized_public_url:
                return payload, str(candidate)
            if normalized_visual_id and normalize_visual_id(payload.get("visualId")) == normalized_visual_id:
                return payload, str(candidate)
    return {}, ""


def classify_printavo_state(
    *,
    explicit_state: str = "",
    invoice_url: str = "",
    public_invoice_url: str = "",
    work_order_url: str = "",
    invoice_status: str = "",
    paid: bool = False,
    extract_type: str = "",
    extract_paid: bool = False,
) -> str:
    normalized_explicit = normalize_text(explicit_state)
    if normalized_explicit in PRINTAVO_STATES:
        return normalized_explicit
    normalized_status = normalize_text(invoice_status).lower()
    if normalize_url(work_order_url):
        return "converted_to_work_order"
    if extract_type.lower() == "invoice" and (normalize_url(invoice_url) or normalize_url(public_invoice_url)):
        return "converted_to_work_order"
    if normalized_status in {"complete", "completed", "production", "in production", "fulfilled"}:
        return "converted_to_work_order"
    if paid or extract_paid:
        return "paid"
    if normalized_status in {"approved", "approval", "approved to print", "customer approved"}:
        return "approved"
    if normalize_url(invoice_url) or normalize_url(public_invoice_url):
        return "quote_live"
    return "needs_more_info_before_printavo"


def recover_urls_from_text(text: str) -> dict[str, str]:
    urls = [normalize_url(match.group(0)) for match in PRINTAVO_URL_PATTERN.finditer(text or "")]
    out = {
        "printavo_invoice_url": "",
        "printavo_public_invoice_url": "",
        "printavo_work_order_url": "",
    }
    for url in urls:
        lowered = url.lower()
        if "/work_orders/" in lowered:
            out["printavo_work_order_url"] = url
        elif "/invoice/" in lowered and "/invoices/" not in lowered:
            out["printavo_public_invoice_url"] = url
        elif "/invoices/" in lowered:
            out["printavo_invoice_url"] = url
    return out
