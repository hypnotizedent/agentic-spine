from __future__ import annotations

import copy
import json
import os
import re
import uuid
from pathlib import Path
from typing import Any

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root as governed_resolve_spine_root
from quote_packet_normalize import dump_yaml, load_structured_file, now_utc


ARTWORK_FAMILY_NAMESPACE = uuid.uuid5(
    uuid.NAMESPACE_URL,
    "https://spine.ronny.works/mint/artwork-family",
)
ARTWORK_ANALYSIS_NAMESPACE = uuid.uuid5(
    uuid.NAMESPACE_URL,
    "https://spine.ronny.works/mint/artwork-intelligence-analysis",
)
RELATIONSHIP_CLASSES = (
    "exact_reuse",
    "prior_art_reuse_with_blank_change",
    "prior_art_reuse_with_size_change",
    "prior_art_variant_existing_asset",
    "new_graphic",
    "ambiguous_needs_operator_review",
)
COLOR_CONTINUITY_STATES = (
    "exact_match",
    "likely_match_needs_confirmation",
    "changed_from_prior",
    "ambiguous_mockup_only",
    "unknown",
)
LOCATION_ALIASES = {
    "left chest": "left_chest",
    "front chest": "left_chest",
    "leftchest": "left_chest",
    "lc": "left_chest",
    "full back": "full_back",
    "back": "full_back",
    "fullback": "full_back",
    "full front": "full_front",
    "front": "full_front",
    "left sleeve": "left_sleeve",
    "sleeve": "left_sleeve",
    "right sleeve": "right_sleeve",
    "hat front": "hat_front",
    "center chest": "center_chest",
}
LOCATION_NOISE = {
    "left",
    "right",
    "front",
    "back",
    "full",
    "chest",
    "sleeve",
    "center",
    "location",
    "print",
}
FAMILY_NOISE = {
    "art",
    "artwork",
    "graphic",
    "design",
    "mockup",
    "proof",
    "print",
    "ready",
    "final",
    "version",
    "rev",
    "revision",
    "updated",
    "new",
}
VARIANT_NOISE = {
    "mockup",
    "proof",
    "final",
    "version",
    "rev",
    "revision",
    "updated",
}
PRODUCT_FAMILY_MAP = {
    "hoodie": "hoodie",
    "sweatshirt": "sweatshirt",
    "crewneck": "sweatshirt",
    "long sleeve": "long_sleeve",
    "long-sleeve": "long_sleeve",
    "spf": "long_sleeve",
    "tee": "t_shirt",
    "shirt": "t_shirt",
    "t-shirt": "t_shirt",
    "polo": "polo",
    "hat": "hat",
    "cap": "hat",
}


def resolve_spine_root() -> Path:
    return governed_resolve_spine_root(__file__)


def resolve_mint_root(spine_root: Path | None = None) -> Path:
    return resolve_mint_data_root(spine_root=spine_root, current_file=__file__)


def runtime_paths(spine_root: Path | None = None) -> dict[str, Path]:
    mint_root = resolve_mint_root(spine_root)
    return {
        "mint_root": mint_root,
        "families_dir": Path(os.environ.get("MINT_ARTWORK_FAMILIES_DIR") or (mint_root / "artwork-families")),
        "families_index_file": Path(
            os.environ.get("MINT_ARTWORK_FAMILIES_INDEX_FILE") or (mint_root / "artwork-families-index.yaml")
        ),
        "analyses_dir": Path(
            os.environ.get("MINT_ARTWORK_INTELLIGENCE_DIR") or (mint_root / "artwork-intelligence")
        ),
        "analyses_index_file": Path(
            os.environ.get("MINT_ARTWORK_INTELLIGENCE_INDEX_FILE") or (mint_root / "artwork-intelligence-index.yaml")
        ),
        "artifacts_dir": Path(os.environ.get("MINT_ARTIFACT_DIR") or (mint_root / "artifacts")),
        "artifacts_index_file": Path(os.environ.get("MINT_ARTIFACT_INDEX_FILE") or (mint_root / "artifacts-index.yaml")),
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
    rows = payload.setdefault(list_key, [])
    existing = next(
        (
            item
            for item in rows
            if isinstance(item, dict) and str(item.get(entity_key) or "") == str(entry.get(entity_key) or "")
        ),
        None,
    )
    if existing:
        existing.update(copy.deepcopy(entry))
    else:
        rows.append(copy.deepcopy(entry))
    dump_yaml(index_file, payload)


def normalize_text(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def normalize_lower(value: Any) -> str:
    return normalize_text(value).lower()


def slug_tokens(value: Any) -> list[str]:
    text = normalize_lower(value)
    if not text:
        return []
    cleaned = re.sub(r"[^a-z0-9]+", " ", text)
    return [token for token in cleaned.split() if token]


def canonical_location(value: Any) -> str:
    text = normalize_lower(value)
    if not text:
        return ""
    return LOCATION_ALIASES.get(text, text.replace(" ", "_"))


def garment_family_from_text(*values: Any) -> str:
    combined = " ".join(normalize_lower(item) for item in values if normalize_text(item))
    for marker, family in PRODUCT_FAMILY_MAP.items():
        if marker in combined:
            return family
    return ""


def size_signature(size_payload: dict[str, Any] | None) -> tuple[float | None, float | None]:
    payload = dict(size_payload or {})
    width = payload.get("width_in")
    height = payload.get("height_in")
    try:
        width_value = round(float(width), 2) if width not in (None, "") else None
    except (TypeError, ValueError):
        width_value = None
    try:
        height_value = round(float(height), 2) if height not in (None, "") else None
    except (TypeError, ValueError):
        height_value = None
    return width_value, height_value


def size_matches(current: dict[str, Any] | None, prior: dict[str, Any] | None, tolerance: float = 0.25) -> bool | None:
    current_width, current_height = size_signature(current)
    prior_width, prior_height = size_signature(prior)
    if current_width is None or current_height is None or prior_width is None or prior_height is None:
        return None
    return abs(current_width - prior_width) <= tolerance and abs(current_height - prior_height) <= tolerance


def family_key_from_text(value: Any) -> str:
    tokens = [token for token in slug_tokens(value) if token not in FAMILY_NOISE and token not in LOCATION_NOISE]
    return "".join(tokens[:8]) or "unclassifiedart"


def variant_key_from_text(value: Any) -> str:
    tokens = [token for token in slug_tokens(value) if token not in VARIANT_NOISE]
    return "".join(tokens[:10]) or family_key_from_text(value)


def pretty_label_from_key(value: str) -> str:
    raw = normalize_text(value)
    if not raw:
        return ""
    spaced = re.sub(r"([a-z])([A-Z])", r"\1 \2", raw.replace("_", " ").replace("-", " "))
    spaced = re.sub(r"\s+", " ", spaced).strip()
    return spaced.title()


def customer_scope_key(customer_binding: dict[str, Any]) -> str:
    binding = dict(customer_binding or {})
    return (
        normalize_lower(binding.get("customer_id"))
        or normalize_lower(binding.get("customer_email"))
        or normalize_lower(binding.get("customer_name"))
        or "unknown-customer"
    )


def artwork_family_id(customer_binding: dict[str, Any], family_key: str) -> str:
    signature = json.dumps(
        {
            "customer_scope": customer_scope_key(customer_binding),
            "family_key": family_key,
        },
        sort_keys=True,
    )
    return str(uuid.uuid5(ARTWORK_FAMILY_NAMESPACE, signature))


def artwork_analysis_id(signature: dict[str, Any]) -> str:
    return str(uuid.uuid5(ARTWORK_ANALYSIS_NAMESPACE, json.dumps(signature, sort_keys=True)))


def normalize_color_truth(raw: dict[str, Any] | None) -> dict[str, Any]:
    payload = dict(raw or {})
    return {
        "ink_colors": [normalize_text(item) for item in (payload.get("ink_colors") or []) if normalize_text(item)],
        "thread_colors": [normalize_text(item) for item in (payload.get("thread_colors") or []) if normalize_text(item)],
        "pms_refs": [normalize_text(item) for item in (payload.get("pms_refs") or []) if normalize_text(item)],
        "thread_refs": [normalize_text(item) for item in (payload.get("thread_refs") or []) if normalize_text(item)],
        "garment_color": normalize_text(payload.get("garment_color")),
        "mockup_color_note": normalize_text(payload.get("mockup_color_note")),
        "mockup_implies_change": bool(payload.get("mockup_implies_change")),
        "confirmation_required": bool(payload.get("confirmation_required")),
        "source_kind": normalize_text(payload.get("source_kind")),
    }


def merge_unique_strings(existing: list[str], new_values: list[str]) -> list[str]:
    output: list[str] = []
    seen: set[str] = set()
    for value in [*existing, *new_values]:
        token = normalize_text(value)
        if not token or token in seen:
            continue
        seen.add(token)
        output.append(token)
    return output


def default_family_record(customer_binding: dict[str, Any], family_key: str, family_label: str = "") -> dict[str, Any]:
    timestamp = now_utc()
    return {
        "family_id": artwork_family_id(customer_binding, family_key),
        "schema_version": "1.0",
        "customer_binding": {
            "customer_id": normalize_text(customer_binding.get("customer_id")) or None,
            "customer_email": normalize_lower(customer_binding.get("customer_email")) or None,
            "customer_name": normalize_text(customer_binding.get("customer_name")) or None,
        },
        "family_key": family_key,
        "family_label": family_label or pretty_label_from_key(family_key),
        "family_status": "active",
        "seed_refs": [],
        "job_refs": [],
        "order_refs": [],
        "variants": [],
        "historical_imprint_truth": [],
        "analysis_refs": [],
        "receipts": {},
        "evidence_refs": {},
        "created_at": timestamp,
        "updated_at": timestamp,
    }


def family_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    customer_binding = dict(record.get("customer_binding") or {})
    return {
        "family_id": record.get("family_id"),
        "customer_id": customer_binding.get("customer_id"),
        "customer_email": customer_binding.get("customer_email"),
        "customer_name": customer_binding.get("customer_name"),
        "family_key": record.get("family_key"),
        "family_label": record.get("family_label"),
        "variant_count": len(record.get("variants") or []),
        "historical_imprint_count": len(record.get("historical_imprint_truth") or []),
        "family_status": record.get("family_status") or "active",
        "updated_at": record.get("updated_at"),
    }


def analysis_index_entry(record: dict[str, Any]) -> dict[str, Any]:
    customer_binding = dict(record.get("customer_binding") or {})
    source_refs = dict(record.get("source_refs") or {})
    summary = dict(record.get("summary") or {})
    return {
        "analysis_id": record.get("analysis_id"),
        "seed_id": record.get("seed_id"),
        "customer_id": customer_binding.get("customer_id"),
        "customer_email": customer_binding.get("customer_email"),
        "customer_name": customer_binding.get("customer_name"),
        "order_id": source_refs.get("order_id"),
        "job_ref": source_refs.get("job_ref"),
        "thread_id": source_refs.get("thread_id"),
        "source_message_id": source_refs.get("source_message_id"),
        "relationship_counts": copy.deepcopy(summary.get("relationship_counts") or {}),
        "color_counts": copy.deepcopy(summary.get("color_continuity_counts") or {}),
        "review_required_count": summary.get("review_required_count") or 0,
        "created_at": record.get("created_at"),
    }
